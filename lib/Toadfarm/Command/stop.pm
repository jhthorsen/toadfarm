package Toadfarm::Command::stop;
use Mojo::Base 'Toadfarm::Command::start';
use Time::HiRes 'usleep';

has description => 'Toadfarm: Stop the server';

sub run {
  my $self    = shift;
  my $signal  = uc(shift || 'QUIT');
  my $moniker = $self->app->moniker;
  my $timeout = ($self->app->config->{hypnotoad}{graceful_timeout} || 20) + 5;

  return $self->_exit("$moniker not running.") unless my $pid = $self->_pid;
  kill $signal, $pid or die "Could not send SIG$signal to $pid: $!\n";

  while ($timeout--) {
    return $self->_exit("$moniker ($pid) stopped.") unless $self->_pid;
  }
  continue {
    usleep 200e3;
  }

  return $self->_exit("$moniker ($pid) failed to stop.", 1);
}

1;

=encoding utf8

=head1 NAME

Toadfarm::Command::stop - Stop a Toadfarm DSL script

=head1 DESCRIPTION

L<Toadfarm::Command::stop> is a command for stopping a L<Toadfarm> application.

=head1 SYNOPSIS

  $ /path/to/script.pl stop

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
