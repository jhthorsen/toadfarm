package Toadfarm::Command::status;
use Mojo::Base 'Toadfarm::Command::start';

use File::Basename 'dirname';
use Mojo::File;
use File::Spec;

has description => 'Toadfarm: Get status from the server';

sub run {
  my ($self, @args) = @_;
  my $moniker  = $self->app->moniker;
  my $pid_file = $self->app->config->{hypnotoad}{pid_file};

  # 0 program is running or service is OK
  # 1 program is dead and /var/run pid file exists
  # 3 program is not running
  # 4 program or service status is unknown

  unless ($pid_file) {
    return $self->_exit("$moniker has invalid config: /hypnotoad/pid_file is not set.", 4);
  }
  unless (-e $pid_file) {
    return $self->_exit("$moniker is not running: No PID file.", 3);
  }

  my ($pid) = Mojo::File->new($pid_file)->slurp =~ /(\d+)/;
  unless ($pid and kill 0, $pid) {
    $pid ||= 0;
    return $self->_exit("$moniker ($pid) is not running, but PID file exists.", 1);
  }

  return $self->_exit("$moniker ($pid) is running.", 0);
}

1;

=encoding utf8

=head1 NAME

Toadfarm::Command::status - Get status from a Toadfarm DSL script

=head1 DESCRIPTION

L<Toadfarm::Command::status> is a command for retrieving status from  a
L<Toadfarm> application.

=head1 SYNOPSIS

  $ /path/to/script.pl status

=head1 ATTRIBUTES

=head2 description

Short description of command, used for the command list.

=head1 METHODS

=head2 run

Run command.

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2014, Jan Henning Thorsen

This program is free software, you can redistribute it and/or modify it under
the terms of the Artistic License version 2.0.

=head1 AUTHOR

Jan Henning Thorsen - C<jhthorsen@cpan.org>

=cut
