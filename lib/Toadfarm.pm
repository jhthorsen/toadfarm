package Toadfarm;

=head1 NAME

Toadfarm - One Mojolicious app to rule them all

=head1 SYNOPSIS

=head2 Production

You can start the application by running:

  $ MOJO_CONFIG=myconfig.conf toadfarm;

C<myconfig.conf> should contain a list with the application you want to run
and a set of HTTP headers to act on. Example:

  {
    apps => [
      'My::App' => {
        'X-Request-Base' => 'http://mydomain.com/whatever',
      },
      'My::Other::App' => {
        'Host' => 'mydomain.com',
      },
    ],
  }

The config above will run C<My::App> when the "X-Request-Base" header is set
to "http://mydomain.com/whatever".

Or it will pass the request on to C<My::Other::App> if the "Host" header is
set to "mydomain.com".

NOTE: "X-Request-Base" is a special header: Normally the
L<route|Mojolicious::Routes> object will be attached to the route object of
the L<Toadfarm> route object. This does not happen with the "X-Request-Base"
header.

NOTE: The apps are processed in the order they are defined. This means that
the first app that match will be executed.

=head2 Debug

It is possible to start the server in foreground as well:

  $ MOJO_CONFIG=myconfig.conf toadfarm prefork
  $ MOJO_CONFIG=myconfig.conf toadfarm daemon

See other options by running:

  $ toadfarm -h

=head1 DESCRIPTION

This application can be used to load other L<Mojolicious> apps inside one app.
This could be useful if you want to save memory or instances on dotcloud or
heroku.

=cut

use Mojo::Base 'Mojolicious';

=head1 AUTHOR

Jan Henning Thorsen - C<jhthorsen@cpan.org>

=cut

1;