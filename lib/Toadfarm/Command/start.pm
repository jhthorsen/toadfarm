package Toadfarm::Command::start;

=head1 NAME

Toadfarm::Command::start - Start a Toadfarm DSL script

=head1 DESCRIPTION

L<Toadfarm::Command::start> is a command for starting a L<Toadfarm::Starter>
application.

=head1 SYNOPSIS

  $ /path/to/script.pl start

=cut

use Mojo::Base 'Mojolicious::Command';

=head1 ATTRIBUTES

=head2 description

Short description of command, used for the command list.

=cut

has description => 'Toadfarm: Start the server if not already running';

=head1 METHODS

=head2 run

Run command.

=cut

sub run {
  my ($self, @args) = @_;
  my $pid     = $self->_pid;
  my $timeout = 5;

  return _exit("Hypnotoad server already running $pid.") if $pid and kill 0, $pid;
  local $ENV{TOADFARM_ACTION} = 'load';
  system hypnotoad => $0;
  _exit("Hypnotoad server failed to start. (@{[$?>>8]})", $?) if $?;

  while ($timeout--) {
    my $pid = $self->_pid or next;
    _exit("Hypnotoad server started $pid.") if $pid and kill 0, $pid;
  }
  continue {
    sleep 1;
  }

  _exit("Hypnotoad server failed to start.", 3);
}

sub _pid {
  my $self = shift;
  my $file = $self->app->config->{hypnotoad}{pid_file} or die "config -> hypnotoad -> pid_file is not set!\n";
  return 0 unless -e $file;
  open my $PID, '<', $file or die "Unable to read pid_file $file: $!\n";
  my $pid = join '', <$PID>;
  return $pid =~ /(\d+)/ ? $1 : 0;
}

sub _exit {
  say $_[0];
  exit($_[1] || 0);
}

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2014, Jan Henning Thorsen

This program is free software, you can redistribute it and/or modify it under
the terms of the Artistic License version 2.0.

=head1 AUTHOR

Jan Henning Thorsen - C<jhthorsen@cpan.org>

=cut

1;
