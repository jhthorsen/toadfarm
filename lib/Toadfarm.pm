package Toadfarm;

=head1 NAME

Toadfarm - One Mojolicious app to rule them all

=head1 VERSION

0.02

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
      '/path/to/my-app' => {
        'Host' => 'mydomain.com',
      },
    ],
  }

The config above will run C<My::App> when the "X-Request-Base" header is set
to "http://mydomain.com/whatever".

Or it will pass the request on to C</path/to/my-app> if the "Host" header is
set to "mydomain.com".

The apps are processed in the order they are defined. This means that the
first app that match will be executed.

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
    log_file => '/path/to/log/file.log',
    hypnotoad => {
      listen => ['http://*:1234'],
      workers => 12,
      # ...
    },
    plugins => [
      MojoPlugin => CONFIG,
    ],
  }

See L<Mojo::Server::Hypnotoad/SETTINGS> for more "hypnotoad" settings.

"plugins" can be used to load plugins into L<Toadfarm>. The plugins are loaded
after the "apps" are loaded. They will receive the C<CONFIG> as the third
argument:

  sub register {
    my($self, $app, CONFIG) = @_;
    # ...
  }

=cut

use Mojo::Base 'Mojolicious';
use Mojo::Util 'class_to_path';

our $VERSION = eval '0.02';

=head1 METHODS

=head2 startup

This method will read the C<MOJO_CONFIG> and mount the applications specified.

=cut

sub startup {
    my $self = shift;
    my $routes = $self->routes;
    my $config = $self->_config;
    my @apps = @{ $config->{apps} || [] };
    my @plugins = @{ $config->{plugins} || [] };
    my $n = 0;

    $self->log->path($config->{log_file}) if $config->{log_file};

    while(@apps) {
      my($path, $rules) = (shift @apps, shift @apps);
      my($app, $r, $request_base, @over);

      delete local $ENV{MOJO_CONFIG};
      $path = class_to_path $path unless -e $path;
      $app = Mojo::Server->new->load_app($path);

      while(my($name, $value) = each %$rules) {
        $request_base = $value if $name eq 'X-Request-Base';
        push @over, "return 0 unless +(\$h->header('$name') // '') eq '$value';\n";
      }

      $r = $routes->route('/*original_path')->detour(app => $app, original_path => '');

      if(@over) {
        unshift @over, "sub { my \$h = \$_[1]->req->headers;\n";
        push @over, "\$_[1]->req->url->base(Mojo::URL->new('$request_base'));" if $request_base;
        push @over, "return 1; }";
        $routes->add_condition("toadfarm_condition_$n", => eval "@over" || die "@over: $@");
        $r->over("toadfarm_condition_$n");
      }

      $n++;
    }

    while(@plugins) {
      my($plugin, $config) = (shift @plugins, shift @plugins);
      $self->plugin($plugin, $config);
    }
}

sub _config {
  my $self = shift;

  return {} if $ENV{TOADFARM_THIS_WILL_PROBABLY_CHANGE};
  die "You need to set MOJO_CONFIG\n" unless $ENV{MOJO_CONFIG};
  $self->plugin('Config');
}

=head1 AUTHOR

Jan Henning Thorsen - C<jhthorsen@cpan.org>

=cut

1;
