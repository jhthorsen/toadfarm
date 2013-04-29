package Toadfarm;

=head1 NAME

Toadfarm - One Mojolicious app to rule them all

=head1 VERSION

0.01

=head1 SYNOPSIS

=head2 Production

You can start the application by running:

  $ toadfarm myconfig.conf;

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

=head1 CONFIG FILE

Additional config params.

  {
    apps => [...], # See SYNOPSIS
    hypnotoad => {
      listen => ['http://*:1234'],
      workers => 12,
      # ...
    },
  }

See L<Mojo::Server::Hypnotoad/SETTINGS> for more "hypnotoad" settings.

=cut

use Mojo::Base 'Mojolicious';

our $VERSION = '0.01';

my %APPS;

=head1 METHODS

=head2 startup

This method will read the C<MOJO_CONFIG> and mount the applications specified.

=cut

sub startup {
    my $self = shift;
    my $config = $self->_config;
    my @apps = @{ $config->{apps} || [] };
    my @cb;

    while(@apps) {
      my($app, $rules) = (shift @apps, shift @apps);
      my $keep_parent = 1;
      my @rules;

      eval "require $app; 1" or die "Could not load $app: $@";
      $APPS{$app} = $app->new;

      while(my($name, $value) = each %$rules) {
        $keep_parent &= $name ne 'X-Request-Base';
        push @rules, "\$h->header('$name') eq '$value'";
      }

      push @cb, "return _dispatch_to_app(\$c, '$app', $keep_parent) if(", join('and', @rules), ');';
    }

    die "Either config file is missing or no apps are defined\n" if !@cb and !$ENV{TOADFARM_THIS_WILL_PROBABLY_CHANGE};
    unshift @cb, 'sub {', 'my $c = shift;', 'my $h = $c->req->headers;';
    push @cb, '$c->render_not_found;', '}';

    $self->routes->route('/*original_path')->to(
      original_path => '',
      cb => eval "@cb" || die "@cb: $@",
    );
}

sub _config {
  my $self = shift;

  return {} if $ENV{TOADFARM_THIS_WILL_PROBABLY_CHANGE};
  die "You need to set MOJO_CONFIG\n" unless $ENV{MOJO_CONFIG};
  $self->plugin('Config');
}

sub _dispatch_to_app {
    my($c, $name, $keep_parent) = @_;
    my $app = $APPS{$name};
    my $r = $app->routes;

    $app->log->debug(qq{Dispatching to application "$name" ($keep_parent).});
    Scalar::Util::weaken($r->parent($c->match->endpoint)->{parent}) if $keep_parent;
    $app->handler($c);
    ++$c->stash->{'mojo.routed'};
}

=head1 AUTHOR

Jan Henning Thorsen - C<jhthorsen@cpan.org>

=cut

1;
