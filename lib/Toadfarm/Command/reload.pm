package Toadfarm::Command::reload;

=head1 NAME

Toadfarm::Command::reload - Reload a Toadfarm DSL script

=head1 DESCRIPTION

L<Toadfarm::Command::reload> is a command for reloading a L<Toadfarm>
application.

=head1 SYNOPSIS

  $ /path/to/script.pl reload
  $ /path/to/script.pl reload --tail <args>

C<--tail> will pass the call L<Toadfarm::Command::tail> after issuing
start/reload on C<script.pl>.

=cut

use Mojo::Base 'Toadfarm::Command::tail';

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
  my $self    = shift;
  my $moniker = $self->app->moniker;

  if (grep {/^--tail/} @_) {
    exec $self->_hypnotoad, $0 unless fork;    # start or hot reload
    return $self->_tail(grep { !/^--tail/ } @_);
  }
  else {
    system $self->_hypnotoad, $0;              # start or hot reload
    my $exit = $? >> 8;
    return $self->_exit("$moniker failed to reload. ($exit)", $exit) if $exit;
  }

  return $self->_exit;
}

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2014, Jan Henning Thorsen

This program is free software, you can redistribute it and/or modify it under
the terms of the Artistic License version 2.0.

=head1 AUTHOR

Jan Henning Thorsen - C<jhthorsen@cpan.org>

=cut

1;
