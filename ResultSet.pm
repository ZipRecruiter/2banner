package YourApp::ResultSet::CurrentlyVisiting;

use strict;
use warnings;
use base 'DBIx::Class::ResultSet';

use Carp qw(croak confess);
use DateTime;
use YourApp::Schema::User;
use YourApp::Schema::CurrentlyVisiting;

# We try but don't guarantee to clean up old records in the CurrentlyVisiting table.
# In any event records are ignored if they are older than this many seconds.
sub max_age { $_[0]{max_age} || 3600 * 2 }

sub dtf {
  my ($self, $dt) = @_;
  my $dtf = $self->result_source->storage->datetime_parser;
  return $dtf->format_datetime($dt);
}

sub now { DateTime->now }
sub now_formatted { $_[0]->dtf($_[0]->now) }
sub oldest {
  my ($self) = @_;
  my $old = $self->now->subtract(seconds => $self->max_age);
  return $self->dtf($old);
}

# Record that someone is currently looking at a page
sub note_arrival {
  my ($self, $arg) = @_;

  my $my_recs = $self->my_recs($arg->{user_id});
  $my_recs->expire_old($arg);
  $my_recs->update_path($arg);
}

# Record that someone has stopped looking at a page
sub note_departure {
  my ($self, $arg) = @_;
  my $my_recs = $self->my_recs($arg->{user_id});
  $my_recs->expire_old($arg);
  $my_recs->search({ page_path => $arg->{page_path} })->delete;
}

sub my_recs {
  my ($self, $uid) = @_;
  defined($uid) or confess "Missing uid argument";
  return $self->result_source->resultset
    ->search_rs({ user_id => $uid });
}

# Ask who is looking at a certain page
# If '$me' is supplied, they are omitted from the results
# Returns an array of { user_id, user_name, arrival_time } hashes
# in no particular order.
sub whos_visiting {
  my ($self, $path, $args) = @_;

  my $max_age = $args->{max_age} // $self->max_age;
  my $me = $args->{me};
  my $rs = $self->search({ page_path => $path,
                           arrival_time => { '>=', $self->oldest },
                           $me ? ("me.user_id" => { '<>', $me->user_id }) : (),
                         }, {
                           prefetch => 'user',
                         });

  my @users;
  while (my $rec = $rs->next) {
    push @users, { user_id      => $rec->user_id,
                   user_name    => $rec->user->name,
                   arrival_time => $rec->arrival_time,
                 };
  }
  return \@users;
}

# Expire old records for a user
# You probably want to call this like this:
#  ->model("CurrentlyVisiting")->search({ user_id => ... })->expire_old(...)
sub expire_old {
  my ($self, $arg) = @_;
  my $my_recs = $self->my_recs($arg->{user_id});

  if ($arg->{ip_address}) {
    $my_recs
      ->search({ ip_address  => { '<>', $arg->{ip_address} }})
      ->delete;
  }

  $self->search({ arrival_time => { '<', $self->oldest }})->delete;
}

# This is the business end of note_arrival
# It updates the date for a user / url pair.
sub update_path {
  my ($self, $arg) = @_;
  my $path_rec = $self->my_recs($arg->{user_id})
      ->search({ page_path => $arg->{page_path} });
  $path_rec->update_or_create({ arrival_time => $self->now_formatted,
                                ip_address   => $arg->{ip_address},
                              },
                              { key => "user_path" });
}

1;

