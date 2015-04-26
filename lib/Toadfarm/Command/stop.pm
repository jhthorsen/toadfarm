package Toadfarm::Command::stop;

=head1 NAME

Toadfarm::Command::stop - Stop a Toadfarm DSL script

=head1 DESCRIPTION

L<Toadfarm::Command::stop> is a command for stopping a L<Toadfarm> application.

=head1 SYNOPSIS

  $ /path/to/script.pl stop

=cut

use Mojo::Base 'Toadfarm::Command::start';
use Time::HiRes 'usleep';

=head1 ATTRIBUTES

=head2 description

Short description of command, used for the command list.

=cut

has description => 'Toadfarm: Stop the server';

=head1 METHODS

=head2 run

Run command.

=cut

sub run {
  my $self    = shift;
  my $signal  = uc(shift || 'QUIT');
  my $timeout = ($self->app->config->{hypnotoad}{graceful_timeout} || 20) + 5;

  $self->_exit("Hypnotoad server not running.") unless my $pid = $self->_pid;
  kill $signal, $pid or die "Could not send SIG$signal to $pid: $!\n";

  while ($timeout--) {
    $self->_exit("Hypnotoad server stopped.") unless $self->_pid;
  }
  continue {
    usleep 200e3;
  }

  $self->_exit("Hypnotoad server failed to stop.", 1);
}

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2014, Jan Henning Thorsen

This program is free software, you can redistribute it and/or modify it under
the terms of the Artistic License version 2.0.

=head1 AUTHOR

Jan Henning Thorsen - C<jhthorsen@cpan.org>

=cut

1;
