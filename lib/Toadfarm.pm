package Toadfarm;

=head1 NAME

Toadfarm - One Mojolicious app to rule them all

=head1 VERSION

0.51

=head1 DESCRIPTION

Toadfarm is a module for configuring and starting your L<Mojolicious>
applications. You can either combine multiple applications in one script,
or just use it as a init script.

Core features:

=over 4

=item *

Wrapper around L<hypnotoad|Mojo::Server::Hypnotoad> that makes your
application L<Sys-V|https://www.debian-administration.org/article/28/Making_scripts_run_at_boot_time_with_Debian>
compatible.

=item *

Advanced routing and virtual host configuration. Also support routing
from behind another web server, such as L<nginx|http://nginx.com/>.
This feature is very much like L<Mojolicious::Plugin::Mount> on steroids.

=item *

Hijacking log messages to a common log file. There's also plugin,
L<Toadfarm::Plugin::AccessLog>, that allows you to log the requests sent
to your server.

=back

=head1 SYNOPSIS

=head2 Script

Here is an example script that sets up logging and mounts some applications
under different domains, as well as loading in some custom plugins.

See L<Toadfarm::Manual::DSL> for more information about the different functions.

  #!/usr/bin/perl
  use Toadfarm -init;

  logging {
    combined => 1,
    file     => "/var/log/toadfarm/app.log",
    level    => "info",
  };

  mount "MyApp"        => {"Host" => "myapp.example.com"};
  mount "/path/to/app" => {"Host" => "example.com", mount_point => "/other"};
  mount "Catch::All::App";

  plugin "Toadfarm::Plugin::AccessLog";
  plugin "Toadfarm::Plugin::Reload" => {
    path => '/some/secret/path', # Specify webhook URL with host other than myapp.example.com or example.com
    repositories => [
      {
        name => 'cool-repo',
        branch => 'some-branch',
        path => '/path/to/cool-repo',
        remote => 'whatever', # defaults to "origin"
      },
    ],
  };

  start; # needs to be at the last line

=head2 Usage

You don't have to put L</Script> in init.d, but it will work with standard
start/stop actions.

  $ /etc/init.d/your-script reload
  $ /etc/init.d/your-script start
  $ /etc/init.d/your-script stop

You can also start the application with normal L<Mojolicious> commands:

  $ morbo /etc/init.d/your-script
  $ /etc/init.d/your-script daemon

=head1 DOCUMENTATION INDEX

=over 4

=item * L<Toadfarm::Manual::Intro> - Introduction.

=item * L<Toadfarm::Manual::DSL> - Domain specific language for Toadfarm.

=item * L<Toadfarm::Manual::Config> - Config file format.

=item * L<Toadfarm::Manual::RunningToadfarm> - Command line options.

=item * L<Toadfarm::Manual::BehindReverseProxy> - Toadfarm behind nginx.

=item * L<Toadfarm::Manual::VirtualHost> - Virtual host setup.

=back

=head1 PLUGINS

=over 4

=item * L<Toadfarm::Plugin::AccessLog>

=item * L<Toadfarm::Plugin::Reload>

=back

=cut

use Mojo::Base 'Mojolicious';
use Mojo::Util qw( class_to_path monkey_patch );
use Cwd 'abs_path';
use File::Basename qw( basename dirname );
use File::Spec;
use File::Which;
use constant DEBUG => $ENV{TOADFARM_DEBUG} ? 1 : 0;

our $VERSION = '0.51';

BEGIN {
  $ENV{TOADFARM_ACTION} //= $ENV{MOJO_APP_LOADER} ? 'load' : (@ARGV and $ARGV[0] =~ /^(reload|start|stop)$/) ? $1 : '';
  $ENV{MOJO_CONFIG} = $ENV{TOADFARM_CONFIG} if $ENV{TOADFARM_CONFIG};
}

sub import {
  return unless grep {/^(-dsl|-init)/} @_;

  my $class  = shift;
  my $caller = caller;
  my $app    = Toadfarm->new;
  my %got;

  $_->import for qw(strict warnings utf8);
  feature->import(':5.10');

  unshift @{$app->commands->namespaces}, 'Toadfarm::Command';

  monkey_patch $caller, (
    app     => sub {$app},
    logging => sub { $got{log}++; $app->_setup_log(@_) },
    mount   => sub { push @{$app->config->{apps}}, @_ == 2 ? @_ : ($_[0], {}); $app },
    plugin  => sub { push @{$app->config->{plugins}}, @_ == 2 ? @_ : ($_[0], {}); $app },
    secrets => sub { $got{secrets} = 1; $app->secrets([@_]) },
    start => sub {
      if (@_) {
        my $listen = ref $_[0] eq 'ARRAY' ? shift : undef;
        $app->config->{hypnotoad} = @_ > 1 ? {@_} : {%{$_[0]}} if @_;
        $app->config->{hypnotoad}{listen} = $listen if $listen;
        $got{hypnotoad}++;
      }

      $app->moniker($class->_moniker) if $app->moniker eq 'toadfarm';
      $app->config->{hypnotoad}{pid_file} ||= $class->_pid_file($app);
      $app = $class->_setup_app($app, \%got) if $ENV{TOADFARM_ACTION} eq 'load';
      warn '$config=' . Mojo::Util::dumper($app->config) if DEBUG;
      $app->start;
    },
  );
}

sub startup {
  my $self = shift;
  my $config = $ENV{MOJO_CONFIG} ? $self->plugin('Config') : {};

  # remember the config when hot reloading the app
  $ENV{TOADFARM_CONFIG} = delete $ENV{MOJO_CONFIG};

  $self->{mounted} = 0;
  $self->_setup_log($config->{log})                   if $config->{log}{file};
  $self->_paths($config->{paths})                     if $config->{paths};
  $self->secrets([$config->{secret}])                 if $config->{secret};
  $self->secrets($config->{secrets})                  if $config->{secrets};
  $self->_mount_apps(@{$config->{apps}})              if $config->{apps};
  $self->_load_plugins(@{$config->{plugins}})         if $config->{plugins};
  $self->_mount_root_app(@{delete $self->{root_app}}) if $self->{root_app};
}

sub _exit { say shift and exit 0 }

sub _load_plugins {
  my $self = shift;

  unshift @{$self->plugins->namespaces}, 'Toadfarm::Plugin';

  while (@_) {
    my ($plugin, $config) = (shift @_, shift @_);
    $self->log->info("Loading plugin $plugin");
    $self->plugin($plugin, $config);
  }
}

sub _moniker {
  my $moniker = basename $0;
  $moniker =~ s!\W!_!g;
  $moniker;
}

sub _mount_apps {
  my $self   = shift;
  my $routes = $self->routes;
  my $config = $self->config;

  while (@_) {
    my ($name, $rules) = (shift @_, shift @_);
    my $server      = Mojo::Server->new;
    my $path        = $name;
    my $mount_point = delete $rules->{mount_point};
    my ($app, $request_base, @over, @error);

    $path = File::Which::which($path) || class_to_path($path) unless -r $path;
    $app ||= eval { $server->load_app($path) }  or push @error, $@;
    $app ||= eval { $server->build_app($name) } or push @error, $@;

    if (!$app) {
      die join "\n", @error;
    }
    if ($config->{log}{combined}) {
      $app->log($self->log);
    }
    if (ref $rules->{config} eq 'HASH') {
      my $local = delete $rules->{config};
      $app->config->{$_} = $local->{$_} for keys %$local;
    }

    $app->config->{$_} ||= $config->{$_} for keys %$config;

    for my $k (qw( local_port remote_address remote_port )) {
      push @over, $self->_skip_if(tx => $k, delete $rules->{$k});
    }

    for my $name (sort keys %$rules) {
      $request_base = $rules->{$name} if $name eq 'X-Request-Base';
      push @over, $self->_skip_if(header => $name, $rules->{$name});
    }

    if (@over) {
      $self->log->info("Mounting $path with conditions");
      unshift @over, "sub { my \$h = \$_[1]->req->headers;\n";
      push @over, "\$_[1]->req->url->base(Mojo::URL->new('$request_base'));" if $request_base;
      push @over, "return 1; }";
      $routes->add_condition("toadfarm_condition_$self->{mounted}", => eval "@over" || die "@over: $@");
      $routes->route($mount_point || '/')->detour(app => $app)->over("toadfarm_condition_$self->{mounted}");
    }
    elsif ($mount_point) {
      $routes->route($mount_point)->detour(app => $app);
    }
    else {
      $self->{root_app} = [$path => $app];
    }

    $self->{mounted}++;
  }

  $self;
}

sub _mount_root_app {
  my ($self, $path, $app) = @_;
  $self->log->info("Mounting $path without conditions.");
  $self->routes->route('/')->detour(app => $app);
}

sub _paths {
  my ($self, $config) = @_;

  for my $type (qw( renderer static )) {
    my $paths = $config->{$type} or next;
    $self->$type->paths($paths);
  }
}

sub _pid_file {
  my ($class, $app) = @_;
  my $name = basename $0;
  my $dir  = dirname abs_path $0;

  return File::Spec->catfile($dir, "$name.pid") if -w $dir;
  return File::Spec->catfile(File::Spec->tmpdir, "toadfarm-$name.pid");
}

sub _setup_app {
  my ($class, $app, $got) = @_;
  my $config = $app->config;

  $app->secrets([Mojo::Util::md5_sum(rand . time . $$ . $0)]) unless $got->{secrets};
  $app->_mount_apps(@{$config->{apps}})      if $config->{apps};
  $app->_load_plugins(@{$config->{plugins}}) if $config->{plugins};

  if (my $root_app = delete $app->{root_app}) {
    if (@{$config->{apps} || []} == 2) {
      my $plugins = $config->{plugins} || [];
      $root_app->[1]->config(hypnotoad => $app->config('hypnotoad')) if $got->{hypnotoad};
      $root_app->[1]->log($app->log) if $got->{log};
      $root_app->[1]->plugin(shift(@$plugins), shift(@$plugins)) for @$plugins;
      $root_app->[1]->secrets($app->secrets) if $root_app->[1]->secrets->[0] eq $root_app->[1]->moniker;
      return $root_app->[1];
    }
    else {
      $app->_mount_root_app(@$root_app);
    }
  }

  return $app;
}

sub _setup_log {
  my ($self, $config) = @_;
  my $log = Mojo::Log->new;

  $self->config(log => $config);
  $log->path($config->{path}) if $config->{path} ||= delete $config->{file};
  $log->level($config->{level} || 'info');
  $self->log($log);
}

sub _skip_if {
  my ($self, $type, $k, $value) = @_;
  my $format = $type eq 'tx' ? '$_[1]->tx->%s' : $type eq 'header' ? q[$h->header('%s')] : q[INVALID(%s)];

  if (!defined $value) {
    return;
  }
  elsif (ref $value eq 'Regexp') {
    return sprintf "return 0 unless +($format || '') =~ /%s/;", $k, $value;
  }
  else {
    return sprintf "return 0 unless +($format || '') eq '%s';", $k, $value;
  }
}

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2014, Jan Henning Thorsen

This program is free software, you can redistribute it and/or modify it
under the terms of the Artistic License version 2.0.

=head1 AUTHOR

Jan Henning Thorsen - C<jhthorsen@cpan.org>

=cut

1;
