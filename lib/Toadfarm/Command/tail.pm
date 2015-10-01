package Toadfarm::Command::tail;

=head1 NAME

Toadfarm::Command::tail - Tail the toadfarm log file

=head1 DESCRIPTION

L<Toadfarm::Command::tail> is a command for tailing the log file used
by the L<Toadfarm> application.

=head1 SYNOPSIS

  $ /path/to/script.pl tail
  $ /path/to/script.pl tail -n 10 -f -q

C<-n> is the number of lines to go back, C<-f> will follow the log and
C<-q> will not print the log file name.

If you like th full power of the C<tail> application instead, you can
do:

  $ tail -f $(/path/to/script.pl tail -n 0)

=cut

use Mojo::Base 'Toadfarm::Command::start';
use Time::HiRes 'usleep';

use constant BUF_SIZE => 4096;    # can probably be any number

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

sub _print {
  shift;
  print @_;
}

sub _tail {
  my $self     = shift;
  my $log_file = $self->app->log->path;
  my $pos      = 0;
  my @lines;

  $self->{opts}{f} = 0;
  $self->{opts}{n} = 10;
  $self->{opts}{q} = 0;

  while (@_) {
    my $opt = shift;
    $self->{opts}{$opt} = $opt =~ /^(-n)/ ? shift || 1 : 1;
  }

  # open and go to end of file
  open my $LOG, '<', $log_file or die "Cannot tail $log_file: $!\n";
  sysseek $LOG, 0, 2;
  $pos = $self->{pos} = tell $LOG;

  $self->_print("$log_file\n") unless $self->{opts}{q};
  $self->_exit unless $self->{opts}{n};

  # go back n-lines
  while (1) {
    my $p = $pos - BUF_SIZE;
    $pos = 0 if $p < 0;
    sysseek $LOG, 0, $pos;
    sysread $LOG, my $buf, BUF_SIZE;
    my @buf = split /\r?\n/, $buf;
    unshift @lines, @buf;
    last if @lines >= $self->{opts}{n} or $pos == 0;
  }

  @lines = splice @lines, -$self->{opts}{n} if @lines > $self->{opts}{n};
  $self->_print("$_\n") for @lines;
  sysseek $LOG, 0, 2;

TAIL: {
    sysseek $LOG, $self->{pos}, 0 if $self->{opts}{f};
    while (<$LOG>) {
      local $| = 1;
      next unless /\r?\n$/;
      $self->_print($_);
      $self->{pos} = tell $LOG;
    }
    last TAIL unless $self->{opts}{f};
    usleep 500e3;
    next TAIL;
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
