package YourApp::Controller::TwoBanner;
use Moose;
BEGIN { extends 'Catalyst::Controller' }

use strict;
use warnings;

use JSON;
use Try::Tiny;

__PACKAGE__->config->{namespace} = 'visit-tracker';

my($debugfh);
if ($ENV{DEBUG_2Banner}) {
  open($debugfh, ">", $ENV{DEBUG_2Banner});
  { my $o  = select $debugfh; $|=1; select $o }
  print $debugfh "Starting at ", scalar(localtime()), "\n";
}

#
# Arrival request
#
# When you arrive at a page, post that page's path to this handler
#
# It will note your arrival in the database and reply with a structure
# listing the other people looking at the same page
#
sub page_arrive : Path('arrive') {
  my ($self, $c) = @_;
  my $cv = $c->model("Schema::CurrentlyVisiting");
  $self->debug("page_arrive:");
  $self->debug("  request method: %s", $c->req->method);
  $self->debug("   content-type: %s", $c->req->content_type);
  $c->detach unless $c->user;

  my $content = $self->content($c);
  $self->check_request($content, [qw[ page_path ]]);
  $self->debug("page_arrive received valid structure; noting arrival");

  $cv->note_arrival({
    page_path    => $content->{page_path},
    user_id      => $c->user->user_id,
    ip_address   => $c->req->address,
    arrival_time => DateTime->now(),
  });

  $c->detach('reply_with_current_visitors', [ $content->{page_path} ]);
}

# Query request
#
# Ask who is visiting a certain page
sub page_query : Path('query') {
  my ($self, $c) = @_;

  my $content = $self->content($c);
  $self->check_request($content, [qw[ page_path ]]);

  $c->detach('reply_with_current_visitors', [ $content->{page_path} ]);
}

#
# Departure request
#
# When you depart a page, post that page's path to this handler
#
# It will note your arrival in the database and reply with a structure
# listing the other people looking at the same page
#
sub page_depart : Path('depart') {
  my ($self, $c) = @_;
  my $cv = $c->model("Schema::CurrentlyVisiting");
  $self->debug("page_depart:");
  $c->detach unless $c->user;

  my $content = $self->content($c);
  $self->check_request($content, [qw[ page_path ]]);
  $self->debug("page_depart received valid structure; noting departure");

  $cv->note_departure({
    page_path    => $content->{page_path},
    user_id      => $c->user->user_id,
    ip_address   => $c->req->address,
  });

  $c->detach('reply');
}

sub reply_with_current_visitors :Private {
  my ($self, $c, $page_path) = @_;

  $c->detach unless $c->user;

  my $cv = $c->model("Schema::CurrentlyVisiting");
  my $others = $cv->whos_visiting($page_path, { me => $c->user });

  # turn DateTime objects into strings
  for my $other (@$others) {
    $other->{arrival_time} = $other->{arrival_time}->iso8601;
  }
  $self->debug("Replying with %d visitors: [%s]",
             0+@$others, join(" ", map {$_->{user_name}} @$others));

  $c->stash(
    json_response => $others,
   );

  $c->detach('reply');
}

sub reply :Private {
  my ($self, $c) = @_;
  my $cur_st = $c->stash->{json_response};
  $c->stash(json_response => 1) unless $cur_st;
  $c->stash(
    current_view  => 'AppAPI',
  );
  $c->detach();
}


sub content :Private {
  my ($self, $c) = @_;
  my $content;
  my $rbody = $c->req->body;
  if ($rbody) {
    # Post requests are stored on the filesystem under certain obscure conditions,
    # in which case $rbody is a filehandle pointing to the temporary file
    if (ref $rbody) {           # a filehandle
      $content = join "", readline($c->req->body);
      unlink $rbody;            # as a string, it names the file
    } else {                    # a string
      $content = $rbody;
    }
  } else {
    # this is mainly here for easier debugging
    # you can issue a GET request for /...?{"page_path":"url"} and it will be treated like 
    # a POST request
    $content = $c->req->query_keywords;
  }
  $self->debug("  c=%s c->req=%s", $c, $c->req);
  $self->debug("  Posted content: <<$content>>");
  my $res = decode_json($content);

  return $res;
}

use Scalar::Util 'reftype';
sub check_request :Private {
  my ($self, $content, $required_keys) = @_;

  unless (ref($content) && reftype($content) eq "HASH") {
    die "Request was not a hash\n";
  }

  for my $rk (@$required_keys) {
    exists $content->{$rk}
      or die "Request is missing required key '$rk'\n";
  }

  return "OK";
}

sub debug {
  return unless $debugfh;
  my ($self, $fmt, @args) = @_;
  print $debugfh scalar(localtime), " ", sprintf($fmt, @args), "\n";
}

1;
