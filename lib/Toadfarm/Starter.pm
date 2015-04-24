package Toadfarm::Starter;

=head1 NAME

Toadfarm::Starter - DSL for defining toadfarm applications

=head1 DESCRIPTION

L<Toadfarm::Starter> is a module that export sugar for defining your
L<Toadfarm> apps. The result is an executable that you can run instead
of the C<toadfarm> executable.

This package and the DSL is EXPERIMENTAL.

=head1 SYNOPSIS

  use Toadfarm::Starter;

  logging {
    combined => 1,
    file     => "/var/log/toadfarm/app.log",
    level    => "info",
  };

  mount "MyApp" => {"Host" => "myapp.example.com"};
  mount "Some::Other::App" => {"Host" => "example.com", mount_point => "/other"};

  plugin "Toadfarm::Plugin::AccessLog";

  secrets "super-secret";

  start;

=cut

use Mojo::Base -strict;
use Mojo::Util 'monkey_patch';
use Cwd 'abs_path';
use File::Basename qw( basename dirname );
use File::Spec;
use Toadfarm;

$ENV{TOADFARM_ACTION} ||= '';

use constant DEBUG => $ENV{TOADFARM_DEBUG} ? 1 : 0;

=head1 FUNCTIONS

These functions are exported to the caller namespace by default. See
L</SYNOPSIS> for example usage.

=head2 app

  $app = app;

Used to fetch the L<Toadfarm> instance that the rest of the functions below
are using.

=head2 logging

  logging {
    combined => 0,
    path     => "/path/to/log/file.log",
    level    => "info",
  };

Used to set up L<Mojo::Log>. See L<Mojo::Log/path> and L<Mojo::Log/level> for
details on the accepted values. C<combined> can be set to true to make all
the L<mounted|/mount> apps use the same L<Mojo::Log> object.

=head2 mount

  mount "/path/to/mojo-app" => \%config;
  mount "My::Mojo::App" => \%config;
  mount "My::Mojo::App";

This function will mount a L<Mojolicious> application, much like
L<Mojolicious::Plugin::Mount> does, but has more options. See
L<Toadfarm::Manual::Config/Apps> for more details.

An application without L<%config> is considered to be a "catch all"
application, meaning that it will get all the requests that does not
match any of the above.

=head2 plugin

  plugin "My::Mojo::Plugin" => \%config;
  plugin "AccessLog";

Used to load a L<Mojolicious::Plugin>. In addition to the default
L<Mojolicious::Plugin> namespace, this application will also
search in the C<Toadfarm::Plugin::> namespace.

=head2 secrets

  secrets @str;

Used to set application L<secrets|Mojolicious/secrets>. A random
secret will be used if none is specified.

=head2 start

  start;
  start \@listen, %config;
  start %config;

Used to start the application. Both C<@listen> and C<%config> are optional,
but will be used to specify the L<Mojo::Server::Hypnotoad> config.

These three examples does the same thing:

  # 1.
  start proxy => 1;
  # 2.
  start ["http://*:8080"], {proxy => 1};
  # 3.
  start {listen => ["http://*:8080"], proxy => 1};

=head1 METHODS

=head2 import

Will export the sugar defined under L</FUNCTIONS>.

=cut

sub import {
  my $class  = shift;
  my $caller = caller;
  my $app    = Toadfarm->new(dsl => 1, argv => [@ARGV]);
  my %got;

  $_->import for qw(strict warnings utf8);
  feature->import(':5.10');

  monkey_patch $caller, (
    app     => sub {$app},
    logging => sub { $got{log}++; $app->_setup_log(@_) },
    mount   => sub { push @{$app->config->{apps}}, @_ == 2 ? @_ : ($_[0], {}); $app },
    plugin  => sub { push @{$app->config->{plugins}}, @_ == 2 ? @_ : ($_[0], {}); $app },
    secrets => sub { $got{secrets} = 1; $app->secrets([@_]) },
    start => sub {
      my $config = $app->config;

      if (@_) {
        my $listen = ref $_[0] eq 'ARRAY' ? shift : undef;
        $config->{hypnotoad} = @_ > 1 ? {@_} : {%{$_[0]}} if @_;
        $config->{hypnotoad}{listen} = $listen if $listen;
        $got{hypnotoad}++;
      }

      $app->moniker($class->_moniker) if $app->moniker eq 'toadfarm';
      $app->config->{hypnotoad}{pid_file} ||= $class->_pid_file($app);
      $class->_start_if_not_running($config->{hypnotoad}{pid_file}) if $ENV{TOADFARM_ACTION} eq 'start';

      if ($ENV{TOADFARM_ACTION} ne 'stop') {
        $app->secrets([Mojo::Util::md5_sum(rand . time . $$ . $0)]) unless $got{secrets};
        $app->_mount_apps(@{$config->{apps}})      if $config->{apps};
        $app->_load_plugins(@{$config->{plugins}}) if $config->{plugins};
      }

      if (my $root_app = delete $app->{root_app}) {
        if (@{$config->{apps} || []} == 2) {
          my $plugins = $config->{plugins} || [];
          $root_app->[1]->config(hypnotoad => $app->config('hypnotoad')) if $got{hypnotoad};
          $root_app->[1]->log($app->log) if $got{log};
          $root_app->[1]->plugin(shift(@$plugins), shift(@$plugins)) for @$plugins;
          $root_app->[1]->secrets($app->secrets) if $root_app->[1]->secrets->[0] eq $root_app->[1]->moniker;
          $app = $root_app->[1];
        }
        else {
          $app->_mount_root_app(@$root_app);
        }
      }

      warn '$config=' . Mojo::Util::dumper($app->config) if DEBUG;

      $app->start;
    },
  );
}

sub _exit { say shift and exit 0 }

sub _moniker {
  my $moniker = basename $0;
  $moniker =~ s!\W!_!g;
  $moniker;
}

sub _pid_file {
  my ($class, $app) = @_;
  my $name = basename $0;
  my $dir  = dirname abs_path $0;

  return File::Spec->catfile($dir, "$name.pid") if -w $dir;
  return File::Spec->catfile(File::Spec->tmpdir, "toadfarm-$name.pid");
}

sub _read_pid {
  my $class = shift;
  my $file = shift or die "config -> hypnotoad -> pid_file is not set!";
  -e $file or return;
  open my $PID, '<', $file or die "Unable to read pid_file $file: $!";
  my $pid = join '', <$PID>;
  return $pid =~ /(\d+)/ ? $1 : 0;
}

sub _start_if_not_running {
  my $class = shift;
  my $pid   = $class->_read_pid(shift);

  _exit("Skip hot deployment for Hypnotoad server $pid.") if $pid and kill 0, $pid;
  $ENV{TOADFARM_ACTION} = '';
  exec hypnotoad => $0;
}

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2014, Jan Henning Thorsen

This program is free software, you can redistribute it and/or modify it under
the terms of the Artistic License version 2.0.

=head1 AUTHOR

Jan Henning Thorsen - C<jhthorsen@cpan.org>

=cut

1;
