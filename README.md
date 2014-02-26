2banner
=======

Notify web users when someone else is looking at the same page

The idea here is that if Fred is looking at web page X, and Mary,
elsewhere, navigates to page X, then a banner should pop up on Fred's
page that says "Mary is also looking at this page" and Mary's page
should load with a similar banner that says "Fred is also looking at
this page".  If Fred navigates away from the page, the banner on
Mary's page will disappear.

Typical use case
----------------

The web pages represent tickets in a customer support system. Fred and
Mary are customer service agents.  Fred was investigating a customer's
request for support, perhaps composing an email to the customer.  The
banner will prevent Mary from independently composing another email to
the same customer; when she sees the banner she will know Fred is
already on the case, and she should handle a different request.

Architecture
------------

This system consists of three components.

The web page has a banner (`2banner.html`).  It has an embedded
Javascript (also `2banner.html`) that periodically makes an
asynchronous HTTP request to an API server, notifying the API server
that the web user is currently viewing a certain page. The response to
the HTTP request includes information about which other users, if any,
are currently viewing the same page.  The embedded Javascript uses
this information to update the banner.  It then waits a few seconds
and repeats.

The API server, written as a Catalyst controller module
(`Catalyst.pm`), receives the requests, which contain JSON parameters.
It makes calls to a database API (`ResultSet.pm`) to modify the
back-end database and to find out what response to send.

The database API (`ResultSet.pm`) presents a high-level interface to
the database, for example `note_arrival` and `whos_visiting`.  These
are implemented in terms of lower-level calls to `search` and
`update`, which are implemented by Perl's `DBIx::Class` module.

Prerequisites
-------------

1. You need a database to store information about which user is
   visiting each page.  The system is database-neutral, but the
   interface supplied here (`ResultSet.pm`, `Schema.pm`) uses the Perl
   [`DBIx::Class`](https://metacpan.org/pod/DBIx::Class) suite.

2. You need an API server to handle requests to query or update the
   database.  The API server (`Catalyst.pm`) supplied with 2banner is
   written using the [Catalyst
   framework](http://www.catalystframework.org/). It should easily
   plug into any Catalyst application.

3. The web pages themselves must be able to send requests to the API
   server, receive responses, and then update the page accordingly.
   The one supplied with 2banner (`2banner.html`) uses [jQuery
   1.9](http://jquery.com/); later versions of jQuery should also
   work.

It should be possible to replace any of 2banner's three components
with your own versions, should that be necessary.  For example, if you
do not use `DBIx::Class`, you can still use 2banner by reimplementing
the database API to make the required database requests some other
way.  If you don't use Catalyst, you can still use 2banner by
implementing your own API server, and borrowing some of the code from
`Catalyst.pm`.

Installation and Integration
----------------------------

<h3>Copy the Perl modules into place</h3>

Install `Catalyst.pm` into the directory where you keep your Catalyst
controller modules, under the name `TwoBanner.pm`.

Install `Schema.pm` into the directory where you keep your
`DBIx::Class` schema modules, under the name `CurrentlyVisiting.pm`.

Install `ResultSet.pm` into the directory where you keep your
`DBIx::Class` resultset modules, under the name
`CurrentlyVisiting.pm`.

Now adjust the class names in the code: each of these three files
starts with a `package` declaration that names its class.  Adjust these
to match the locations of the files.  Additionally:

  * `Schema.pm` contains

        __PACKAGE__->resultset_class('YourApp::ResultSet::CurrentlyVisiting');

     which should be adjusted to contain the new class name of `ResultSet.pm`

  * `ResultSet.pm` contains

        use YourApp::Schema::CurrentlyVisiting

     which should be adjusted to contain the current name of
    `Schema.pm`.

<h3>Interface with your table of users</h3>

The main change you must make is to integrate 2banner with your
pre-existing table of user information.  As written, 2banner assumes:

* that you have a table called `user`

* that it contains a `user_id` field which is a SQL `INT(10)`

* that it also contains a `name` field which might be useful to include in
  the banner text

* that there is a `DBIx::Class` schema class that represents it,
  called `YourSchema::Schema::User`.

You may need to adjust these assumptions, as follows:

* In `currently_visiting.sql` adjust the type of the `user_id` field
  to match the type of the ID field in your existing user table.

        user_id               int(10)       not null,

   2banner will try to join `currently_visiting` to the pre-existing
   `user` table, using the `user_id`, to get username information
   using this field.

   Uncomment and adjust the `foreign key` declaration if you want
   that:

         -- foreign key (user_id)      references user (user_id),

* In `Schema.pm`, adjust the line: 

         __PACKAGE__->belongs_to('user' => 'YourSchema::Schema::User',
                            { 'foreign.user_id' => 'self.user_id'},
                            { cascade_delete => 0 });

  Change `YourSchema::Schema::User` to the name of the `DBIx::Class`
  class that represents your user table.  If the primary key in the
  user table is called something other than `user_id`, change
  `foreign.user_id` to match.

* In `ResultSet.pm`: 

  1. Adjust `use YourApp::Schema::User;` to load the `DBIx::Class`
     schema class for your user table.

  2. In `whos_visiting`, adjust the code:

            push @users, { user_id      => $rec->user_id,
	                   user_name    => $rec->user->name,
		           arrival_time => $rec->arrival_time,
		         };

     This controls what information can be exposed in the web page.  If
     your `user` table calls usernames something other than `name`,
     change it here.  If it has a `real_name` field, you can expose
     that by adding a line like this:

                   real_name    => $rec->user->real_name,

     The `@users` array is exactly what is returned to the web page
     in response to the API request.


<h3>Which user is looking at the page?</h3>

The Catalyst API server assumes that the web user's identity is
available via a call to `$c->user`, and that `$c->user->user_id` will
retrieve a user ID that can be used to look up records.  Requests from
non-users are disregarded, and no useful information is returned.

Catalyst has plugins that will populate `$c->user` appropriately,
depending on your site policy.

<h3>Create the database table</h3>

   Execute `currently_visiting.sql` to create the table.  I use
   something like this:

          mysql -v -uusername -ppassword database-name < currently_visiting.sql

<h3>Time and time zone hassles</h3>


* `ResultSet.pm` has a `now` method that uses the call `DateTime->now`
   to generate the current time.  This may or may not include time
   zone information, depending on your local system; depending on just
   how things are set up, you might have time mismatches where some
   time is being written as local time but interpreted as UTC, or vice
   versa.  It hard for me to say from this end.

   In any event, you may prefer a different method for getting the
   current time; if so, adjust this method.  At ZipRecruiter we store
   all times in US Pacific, so instead of `DateTime->now` here we
   use a call that expands to

           DateTime->now->set_time_zone( $time_zone_los_angeles );


* `Catalyst.pm` similarly uses `DateTime->now` here:

              $cv->note_arrival({
                page_path    => $content->{page_path},
                user_id      => $c->user->user_id,
                ip_address   => $c->req->address,
                arrival_time => DateTime->now(),
              });

<h3>Integrate banner into your pages</h3>

The complete code for the banner itself is in `2banner.html`.  You
should arrange to have this inserted into a web page on which you want
the banner to appear. At ZipRecruiter, our pages are stored as `TT2`
template files, and we use

        [% INCLUDE 'admin/2banner.html' %]

to incorporate the 2banner in the pages that want it.

Configuration
-------------

* The API server will appear in your Catalyst application at the
  following URLs:

  * `/visit-tracker/arrive`
  * `/visit-tracker/depart`
  * `/visit-tracker/query`

  To change the `visit-tracker` component, adjust the line
  `__PACKAGE__->config->{namespace} = 'visit-tracker';` in
  `Catalyst.pm`.  You will want to adjust the two `url:` parameters in
  the Ajax calls in `2banner.html`.

* Update frequency

  Web pages displaying the 2banner will contact the API server
  periodically and refresh the banner if conditions change.  By
  default, they do this every 5 seconds.  I suggest that you adjust
  this downward during installation and debugging, and then upward for
  production use.  `2banner.html` contains the line

        var default_update_interval = 5000;

  The 5000 here is a number of milliseconds is the time the page will
  wait after updating the banner before tries again to contact the API
  server.

* Banner styling

  The default banner styling is hideous but obvious. It is contained
  in `2banner.html`:

        <!-- get someone to make this less horrible-looking -->
        <div id="the2Banner" style="background: orange; font-size: 18pt;
          foreground-color: black;">(loading...)</div>

Debugging
---------

* If the environment variable `$DEBUG_2Banner` is set to the name of a
  file, the Catalyst API server will print a log of its actions to
  that file.  To emit a log message to the file, print to the
  file-global filehandle `$debugfh` or call the `debug` method, which
  takes arguments like `sprintf`s.

* In `ResultSet.pm` you can get `DBIx::Class` to diagnose the actual
  database requests by setting the environment variable `$DBIC_TRACE`
  to 1, or by inserting a line of code like

         $self->result_source->storage->debug(1);

  to turn on tracing.  See the `DBIx::Class` manual for more details.

* Query URLs

  The `/visit-tracker/arrive` and `/visit-tracker/depart` API calls
  are normally expecting to be called with HTTP POST methods.  But you
  can invoke them with GET methods instead, which are easier to
  generate from a browser.  A request like:

          http://.../visit-tracker/arrive?{"page_path":"some-url"}

  will notify the API that the current user has arrived at `some-url`.
  `depart` is similar.

* Ajax diagnostic panel

  `2banner.html` contains a diagnostic panel that can display
  notifications about what the Ajax calls are doing.  To display it, find

            <!-- this is for for debugging. Set "visibility: visible" to display it  -->
            <div id="2bd" style="visibility: hidden; background: white; font-size: 18pt; foreground-color: black;">(diagnostics)</div>

  and change `visibility: hidden` to `visibility: visible`.

  To modify the message in the diagnostic panel, use something like:

            $('#2bd').html("your message here");

  The `2banner.html` file contains numerous examples of this.

Questions?
----------

I can't promise to help, but if you email me at `mjd@ziprecruiter.com`
I will read your message and I may reply.

