package Toadfarm::Command::rebase;

=head1 NAME

Toadfarm::Command::rebase - Used to update git repo and restart application

=head1 DESCRIPTION

This command will run the commands below to load in new code into the current
server.

  $ git remote update
  $ git rebase origin/$branch
  $ hypnotoad $0;

=cut

use Mojo::Base 'Mojolicious::Command';

our $GIT = $ENV{GIT_EXE} || 'git';
our $HYPNOTOAD = 'hypnotoad';

=head1 ATTRIBUTES

=head2 description

=head2 usage

=cut

has description => "Used to update git repo and restart application.\n";
has usage => <<"USAGE";
usage $0 rebase <branch>
USAGE

=head1 METHODS

=head2 run

See L</DESCRIPTION>.

=cut

sub run {
    @_ == 2 or die shift->usage;
    my($self, $branch) = @_;
    my $FH = \*STDOUT; # TODO

    $self->_run($FH, $GIT => remote => 'update');
    $self->_run($FH, $GIT => log => '--oneline', "$branch..origin/$branch");
    $self->_run($FH, $GIT => rebase => "origin/$branch");
    $self->_run($FH, $HYPNOTOAD => $0);
}

sub _run {
  my($self, $FH, @cmd) = @_;

  # TODO:
  # IPC::Run3::run3(\@cmd, \undef, $FH, $FH);
  system @cmd;
}

=head1 AUTHOR

Jan Henning Thorsen - C<jhthorsen@cpan.org>

=cut

1;