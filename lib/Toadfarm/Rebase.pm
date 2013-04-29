package Toadfarm::Rebase;

=head1 NAME

Toadfarm::Rebase - Restart hypnotoad with new code

=head1 SYNOPSIS

=head2 Toadfarm config

  {
    # ...
    plugins => [
      'Toadfarm::Rebase' => {
        path => '/my-super-duper-secret-restart-path',
        ref => 'refs/heads/my-production-branch',
      },
    ],
  }

=head2 Mojolicious app

  $self->plugin('Toadfarm::Rebase', { ... });

=head1 DESCRIPTION

This L<Mojolicious> plugin allow the hypnotoad server to restart when a
resource is hit with a special JSON payload. The payload is compatible with
the post receive hook github use:
L<https://help.github.com/articles/post-receive-hooks>

=head1 DISCLAIMER

I'm not sure if this is a good idea.

=cut

use Mojo::Base 'Mojolicious::Plugin';

=head1 METHODS

=head2 register

  $self->register($app, \%config);

See L</SYNOPSIS> for C<%config> parameters.

=cut

sub register {
  my($self, $app, $config) = @_;
  my $ref = $config->{ref};
  my($branch) = $ref =~ m!/([\w-]+)$!;
  my $t0 = localtime $^T;

  $app->routes->any($config->{path})->to(cb => sub {
    my $c = shift;
    my($payload, $pid);

    if($c->req->method ne 'POST') {
      return $c->render_json({ start => $t0 });
    }

    $payload = $c->req->body_params->param('payload');
    $payload = Mojo::JSON->new->decode($payload);
    $payload->{ref} ||= 'UNKNOWN';

    $SIG{CHLD} = 'IGNORE';
    return $c->render_json({}, status => 400) unless $payload->{ref} eq $ref;
    $c->app->log->info("exec $0 rebase $branch ($payload->{ref})");
    return $c->render_json({ rebasing => 1 }, status => 200) if $pid = fork;
    return $c->render_json({}, status => 500) unless defined $pid;

    # child
    delete $ENV{HYPNOTOAD_PID};
    delete $ENV{HYPNOTOAD_REV};
    { exec $0 => rebase => $branch }
    $c->app->log->error("exec $0 rebase $branch: $!");
    exit;
  });
}

=head1 AUTHOR

Jan Henning Thorsen - C<jhthorsen@cpan.org>

=cut

1;