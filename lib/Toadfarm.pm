package Toadfarm;

=head1 NAME

Toadfarm - One Mojolicious app to rule them all

=head1 VERSION

0.41

=head1 DESCRIPTION

Toadfarm is wrapper around L<hypnotoad|Mojo::Server::Hypnotoad> that allow
you to mount many L<Mojolicious> applications inside one hypnotoad server.

See also L<Mojolicious::Plugin::Mount>. The mount plugin is useful if
your applications are hard coupled, while Toadfarm provide functionality
to route requests to a standalone application based on HTTP headers instead
of the request path.

C<toadfarm> can also be useful for standalone applications, since it allows
starting applications via C<crontab>:

  * * * * * /usr/local/bin/toadfarm -a toadfarm --start 1>/tmp/toadfarm.cron.log 2>&1

=head1 SYNOPSIS

You can start the application by running:

  $ toadfarm myconfig.conf;

C<myconfig.conf> should contain a list with the application you want to run
and a set of HTTP headers to act on. Example:

  {
    apps => [
      'My::App' => {
        'X-Request-Base' => 'http://mydomain.com/whatever',
        'config' => { app_config => 123 },
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
first app that matchs will be executed.

=head2 Application config

The application will load the config as you would expect, but it is also
possible to override the app config from the toadfarm config. This is
especially useful when starting an app installed from cpan:

  apps => {
    # https://metacpan.org/module/App::mojopaste
    '/usr/local/bin/mojopaste' => {
      Host => 'p.thorsen.pm',
      config => {
        paste_dir => '/some/other/location
      },
    },
  },

NOTE! This will override the default application config.

=head2 Command line options

C<toadfarm> understands these options:

  -a <path>          Custom application (other than toadfarm)
  -a <class>         Custom application class
  -f, --foreground   Keep manager process in foreground.
  -h, --help         Show this message.
      --man          Show manual
      --start        Only start - no hot reload
  -s, --stop         Stop server gracefully.
  -t, --test         Test application and exit.

Default config file will be C<$HOME/.toadfarm/$app.conf>, where
C<$app> is specified by "-a".

  toadfarm -a toadfarm B<is the same as> toadfarm "$HOME/.toadfarm/toadfarm.conf"

When loading a class C<My::App>, the config file be
C<$HOME/.toadfarm/my-app.conf>.

Examples:

  # Start or hot reload application
  toadfarm path/to/apps.conf

  # Start and print status
  toadfarm --start path/to/apps.conf

  # Custom application
  toadfarm -a /path/to/myapp.pl path/to/mojo.conf
  toadfarm -a My::App path/to/mojo.conf

=head2 Debug

It is possible to start the server in the foreground as well:

  $ MOJO_CONFIG=myconfig.conf toadfarm prefork
  $ MOJO_CONFIG=myconfig.conf toadfarm daemon

See other options by running:

  $ toadfarm -h

=head1 CONFIG FILE

Additional config params.

  {
    apps => [...], # See SYNOPSIS
    secrets => [qw( super duper unique string )], # See Mojolicious->secrets()
    log => {
      file => '/path/to/log/file.log',
      level => 'debug', # debug, info, warn, ...
      combined => 1, # true to make all applications log to the same file
    },
    hypnotoad => {
      listen => ['http://*:1234'],
      workers => 12,
      # ...
    },
    paths => {
      renderer => [ '/my/custom/template/path' ],
      static => [ '/my/custom/static/path' ],
    },
    plugins => [
      MojoPlugin => CONFIG,
    ],
  }

=over 4

=item * log

Used to set up where L<Toadfarm> should log to. It is also possible to set
"combined" to true if you want all the other apps to log to the same file.

=item * hypnotoad

See L<Mojo::Server::Hypnotoad/SETTINGS> for more "hypnotoad" settings.

=item * paths

Set this to enable custom templates and public files for this application.
This is useful if you want your own error templates or serve other assets from
L<Toadfarm>.

=item * plugins

"plugins" can be used to load plugins into L<Toadfarm>. The plugins are loaded
after the "apps" are loaded. They will receive the C<CONFIG> as the third
argument:

  sub register {
    my($self, $app, CONFIG) = @_;
    # ...
  }

See also: L<Toadfarm::Plugin::Reload/SYNOPSIS>.

=back

=head1 EXAMPLE SETUP

Look at L<https://github.com/jhthorsen/toadfarm/tree/master/etc> for example
resources which show how to start L<Toadfarm> on ubuntu. In addition, you can
forward all traffic to the server using the "iptables" rule below:

  $ iptables -A PREROUTING -i eth0 -p tcp -m tcp --dport 80 -j REDIRECT --to-ports 8080

=head1 PLUGINS

L<Toadfarm::Plugin::Reload>.

=cut

use Mojo::Base 'Mojolicious';
use Mojo::Util 'class_to_path';
use File::Which;

our $VERSION = '0.41';

$ENV{MOJO_CONFIG} = $ENV{TOADFARM_CONFIG} if $ENV{TOADFARM_CONFIG};

=head1 METHODS

=head2 startup

This method will read the C<MOJO_CONFIG> and mount the applications specified.

=cut

sub startup {
  my $self = shift;
  my $config = $ENV{MOJO_CONFIG} ? $self->plugin('Config') : {};

  # remember the config when hot reloading the app
  $ENV{TOADFARM_CONFIG} = delete $ENV{MOJO_CONFIG};

  if($config->{log}{file}) {
    my $log = Mojo::Log->new;
    $log->path($config->{log}{file});
    $log->level($config->{log}{level} || 'info');
    $self->log($log);
  }

  for my $type (qw/ renderer static /) {
    my $paths = $config->{paths}{$type} or next;
    $self->$type->paths($paths);
  }

  $self->secrets([$config->{secret}]) if $config->{secret};
  $self->secrets($config->{secrets}) if $config->{secrets};
  $self->_start_apps(@{ $config->{apps} }) if $config->{apps};
  $self->_start_plugins(@{ $config->{plugins} }) if $config->{plugins};

  # need to add the root app afterwards
  if(my $app = delete $self->{root_app}) {
    $self->log->info("Mounting $app->[0] without condition");
    $self->routes->route('/')->detour(app => $app->[1]);
  }
}

sub _start_apps {
  my $self = shift;
  my $routes = $self->routes;
  my $config = $self->config;
  my $n = 0;

  if($config->{log}{combined}) {
    $self->log->info('All apps will log to ' .$config->{log}{file});
  }

  while(@_) {
    my($name, $rules) = (shift @_, shift @_);
    my $server = Mojo::Server->new;
    my $path = $name;
    my($app, $request_base, @over, @error);

    $path = File::Which::which($path) || class_to_path($path) unless -r $path;
    $app ||= eval { $server->load_app($path) } or push @error, $@;
    $app ||= eval { $server->build_app($name) } or push @error, $@;

    if(!$app) {
      die join "\n", @error;
    }
    if($config->{log}{combined}) {
      $app->log($self->log);
    }
    if(ref $rules->{config} eq 'HASH') {
      my $local = delete $rules->{config};
      $app->config->{$_} = $local->{$_} for keys %$local;
    }

    $app->config->{$_} ||= $config->{$_} for keys %$config;

    while(my($name, $value) = each %$rules) {
      $request_base = $value if $name eq 'X-Request-Base';
      push @over, ref $value
        ? "return 0 unless +(\$h->header('$name') // '') =~ /$value/;\n"
        : "return 0 unless +(\$h->header('$name') // '') eq '$value';\n";
    }

    if(@over) {
      $app->log->info("Mounting $path with conditions");
      unshift @over, "sub { my \$h = \$_[1]->req->headers;\n";
      push @over, "\$_[1]->req->url->base(Mojo::URL->new('$request_base'));" if $request_base;
      push @over, "return 1; }";
      $routes->add_condition("toadfarm_condition_$n", => eval "@over" || die "@over: $@");
      $routes->route('/')->detour(app => $app)->over("toadfarm_condition_$n");
    }
    else {
      $self->{root_app} = [ $path => $app ];
    }

    $n++;
  }

  $self;
}

sub _start_plugins {
  my $self = shift;

  unshift @{ $self->plugins->namespaces }, 'Toadfarm::Plugin';

  while(@_) {
    my($plugin, $config) = (shift @_, shift @_);
    $self->log->info("Loading plugin $plugin");
    $self->plugin($plugin, $config);
  }
}

=head1 AUTHOR

Jan Henning Thorsen - C<jhthorsen@cpan.org>

=cut

1;

1;
