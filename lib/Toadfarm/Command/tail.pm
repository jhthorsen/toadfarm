package Toadfarm::Command::tail;

=head1 NAME

Toadfarm::Command::tail - Tail the toadfarm log file

=head1 DESCRIPTION

L<Toadfarm::Command::tail> is a command for tailing the log file used
by the L<Toadfarm> application.

=head1 SYNOPSIS

  $ /path/to/script.pl tail
  $ /path/to/script.pl tail -n 10 -f -q

The tail command will start tailig from the end of file. Any options
passed after the "tail" command will issue C<tail> to be started
instead, with the given arguments.

=cut

use Mojo::Base 'Toadfarm::Command::start';
use Time::HiRes 'usleep';

use constant BUF_SIZE => 4096;                       # can probably be any number
use constant TAIL_EXE => $ENV{TAIL_EXE} || 'tail';

our $VERSION = '0.01';

=head1 ATTRIBUTES

=head2 description

Short description of command, used for the command list.

=cut

has description => 'Toadfarm: Tail the log file';

=head1 METHODS

=head2 run

Run command.

=cut

sub run { shift->_tail(@_) }

sub _tail {
  my $self     = shift;
  my $log_file = $self->app->log->path;

  $self->_exit('Unknown log file.', 2) unless $log_file;
  exec TAIL_EXE, @_, $log_file if @_;

  # open and go to end of file
  open my $LOG, '<', $log_file or die "Cannot tail $log_file: $!\n";
  my $pos = -s $log_file;
  warn "\$ tail -f $log_file\n";

  while (1) {
    seek $LOG, $pos, 0;
    while (<$LOG>) {
      local $| = 1;
      print $_;
      $pos = tell $LOG;
    }
    usleep 500e3;
  }

  $self->_exit;
}

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2014, Jan Henning Thorsen

This program is free software, you can redistribute it and/or modify it under
the terms of the Artistic License version 2.0.

=head1 AUTHOR

Jan Henning Thorsen - C<jhthorsen@cpan.org>

=cut

1;
