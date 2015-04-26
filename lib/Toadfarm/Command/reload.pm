package Toadfarm::Command::reload;

=head1 NAME

Toadfarm::Command::reload - Reload a Toadfarm DSL script

=head1 DESCRIPTION

L<Toadfarm::Command::reload> is a command for reloading a L<Toadfarm>
application.

=head1 SYNOPSIS

  $ /path/to/script.pl reload

=cut

use Mojo::Base 'Toadfarm::Command::start';

=head1 ATTRIBUTES

=head2 description

Short description of command, used for the command list.

=cut

has description => 'Toadfarm: Hot deploy or start the server';

=head1 METHODS

=head2 run

Run command.

=cut

sub run {
  my $self = shift;
  local $ENV{TOADFARM_ACTION} = 'load';
  system hypnotoad => $0;
  $self->_exit("Hypnotoad server failed to reload. (@{[$?>>8]})", $?) if $?;
}

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2014, Jan Henning Thorsen

This program is free software, you can redistribute it and/or modify it under
the terms of the Artistic License version 2.0.

=head1 AUTHOR

Jan Henning Thorsen - C<jhthorsen@cpan.org>

=cut

1;
