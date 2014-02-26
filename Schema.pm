
package YourApp::Schema::CurrentlyVisiting;

use strict;
use warnings;

use base 'DBIx::Class';

__PACKAGE__->load_components( qw(InflateColumn::DateTime Core) );

__PACKAGE__->table('currently_visiting');

# TBD: better to read the columns automatically?
__PACKAGE__->add_columns(
  currently_visiting_id => {},
  page_path             => {},
  user_id               => {},
  arrival_time          => { data_type => 'datetime' },
  ip_address            => {},
);

__PACKAGE__->set_primary_key('currently_visiting_id');

__PACKAGE__->add_unique_constraint(
  user_path => [ qw/user_id page_path/ ],
 );

__PACKAGE__->resultset_class('YourApp::ResultSet::CurrentlyVisiting');

=head1 RELATIONSHIPS

=cut

__PACKAGE__->belongs_to('user' => 'YourApp::Schema::User',
                        { 'foreign.user_id' => 'self.user_id'},
                        { cascade_delete => 0 });


1;
