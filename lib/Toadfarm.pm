package Toadfarm;

=head1 NAME

Toadfarm - One Mojolicious app to rule them all

=head1 VERSION

0.45

=head1 DESCRIPTION

Toadfarm is wrapper around L<hypnotoad|Mojo::Server::Hypnotoad> that allow
you to mount many L<Mojolicious> applications inside one hypnotoad server.

The L<Mojolicious::Plugin::Mount> plugin is useful if your applications
are hard coupled, while Toadfarm provide functionality to route requests
to a standalone application based on HTTP headers instead. This is
functionality that you expect from a reverse proxy, such as Nginx.

=head1 DOCUMENTATION INDEX

=over 4

=item * L<Toadfarm::Manual::Intro> - Introduction.

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
use Mojo::Util 'class_to_path';
use File::Which;

our $VERSION = '0.45';

$ENV{MOJO_CONFIG} = $ENV{TOADFARM_CONFIG} if $ENV{TOADFARM_CONFIG};

sub startup {
  my $self = shift;
  my $config = $ENV{MOJO_CONFIG} ? $self->plugin('Config') : {};

  # remember the config when hot reloading the app
  $ENV{TOADFARM_CONFIG} = delete $ENV{MOJO_CONFIG};

  if ($config->{log}{file}) {
    my $log = Mojo::Log->new;
    $log->path($config->{log}{file});
    $log->level($config->{log}{level} || 'info');
    $self->log($log);
  }

  for my $type (qw/ renderer static /) {
    my $paths = $config->{paths}{$type} or next;
    $self->$type->paths($paths);
  }

  $self->secrets([$config->{secret}])          if $config->{secret};
  $self->secrets($config->{secrets})           if $config->{secrets};
  $self->_start_apps(@{$config->{apps}})       if $config->{apps};
  $self->_start_plugins(@{$config->{plugins}}) if $config->{plugins};

  # need to add the root app afterwards
  if (my $app = delete $self->{root_app}) {
    $self->log->info("Mounting $app->[0] without conditions.");
    $self->routes->route('/')->detour(app => $app->[1]);
  }
}

sub _start_apps {
  my $self   = shift;
  my $routes = $self->routes;
  my $config = $self->config;
  my $n      = 0;

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
      $routes->add_condition("toadfarm_condition_$n", => eval "@over" || die "@over: $@");
      $routes->route($mount_point || '/')->detour(app => $app)->over("toadfarm_condition_$n");
    }
    elsif ($mount_point) {
      $routes->route($mount_point)->detour(app => $app);
    }
    else {
      $self->{root_app} = [$path => $app];
    }

    $n++;
  }

  $self;
}

sub _start_plugins {
  my $self = shift;

  unshift @{$self->plugins->namespaces}, 'Toadfarm::Plugin';

  while (@_) {
    my ($plugin, $config) = (shift @_, shift @_);
    $self->log->info("Loading plugin $plugin");
    $self->plugin($plugin, $config);
  }
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
