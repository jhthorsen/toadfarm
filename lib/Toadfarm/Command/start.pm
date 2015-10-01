package Toadfarm::Command::start;

=head1 NAME

Toadfarm::Command::start - Start a Toadfarm DSL script

=head1 DESCRIPTION

L<Toadfarm::Command::start> is a command for starting a L<Toadfarm> application.

=head1 SYNOPSIS

  $ /path/to/script.pl start

=cut

use Mojo::Base 'Mojolicious::Command';
use File::Basename 'dirname';
use File::Spec;

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

  $self->_exit("Hypnotoad server already running $pid.") if $pid and kill 0, $pid;
  system $self->_hypnotoad, $0;
  $self->_exit("Hypnotoad server failed to start. (@{[$?>>8]})", $?) if $?;

  while ($timeout--) {
    my $pid = $self->_pid or next;
    $self->_exit("Hypnotoad server started $pid.") if $pid and kill 0, $pid;
  }
  continue {
    sleep 1;
  }

  $self->_exit("Hypnotoad server failed to start.", 3);
}

sub _exit {
  say $_[1] if $_[1];
  exit($_[2] || 0);
}

sub _hypnotoad {
  my $self = shift;

  for my $p (File::Spec->path, dirname($^X)) {
    my $exe = File::Spec->catfile($p, 'hypnotoad');
    return $exe if -r $exe;
  }

  die "Cannot find 'hypnotoad' in \$PATH.";
}

sub _pid {
  my $self = shift;
  my $file = $self->app->config->{hypnotoad}{pid_file} or die "config -> hypnotoad -> pid_file is not set!\n";
  return 0 unless -e $file;
  open my $PID, '<', $file or die "Unable to read pid_file $file: $!\n";
  my $pid = join '', <$PID>;
  return $pid =~ /(\d+)/ ? $1 : 0;
}

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2014, Jan Henning Thorsen

This program is free software, you can redistribute it and/or modify it under
the terms of the Artistic License version 2.0.

=head1 AUTHOR

Jan Henning Thorsen - C<jhthorsen@cpan.org>

=cut

1;
