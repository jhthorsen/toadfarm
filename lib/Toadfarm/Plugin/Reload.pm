package Toadfarm::Plugin::Reload;

=head1 NAME

Toadfarm::Plugin::Reload - Reload toadfarm with new code

=head1 DESCRIPTION

This L<Mojolicious> plugin allow the L</Toadfarm> server to restart when a
resource is hit with a special JSON payload. The payload need to be compatible with
the L<post-receive-hook|https://help.github.com/articles/post-receive-hooks> github use.

=head1 SETUP

=over 4

=item *

You need to set up a post receive hook on github to make this reloader work.
Go to "https://github.com/jhthorsen/YOUR-REPO/settings/hooks" to set it up.

=item *

The WebHook URL need to be "http://yourserver.com/some/secret/path".
See L<CONFIG|/path> below for details.

=back

=head1 CONFIG

This is a config template for L<Toadfarm>:

  {
    apps => [...],
    plugins => [
      Reload => {
        path => '/some/secret/path',
        repositories => {
          'cool-repo' => {
            branch => 'some-branch',
            path => '/path/to/cool-repo',
            remote => 'whatever', # defaults to "origin"
          },
        },
      },
      # ...
    ],
  }

Details:

=over 4

=item * path

This should be the path part of the URL to POST data to reload the server.
Make this something semi secret to avoid random requests:

  perl -le'print join "/", "", "reload", (time.$$.rand(9999999)) =~ /(\w\w)/g'

=item * repositories

This should contain a mapping between github repository names and local settings:

=over 4

=item * branch

This need to match the branch which you push to github. It should be something
like "production", and not "master" - unless you want every push to master to
reload the server.

=item * path

This is the path on disk to the local git repo.

=back

=back

=cut

use Mojo::Base 'Mojolicious::Plugin';
use Mojo::JSON;

our $GIT = $ENV{GIT_EXE} || 'git';

=head1 METHODS

=head2 register

  $self->register($app, \%config);

See L</SYNOPSIS> for C<%config> parameters.

=cut

sub register {
  my($self, $app, $config) = @_;
  my $t0 = localtime $^T;

  $self->_valid_config($config) or return;
  $self->{log} = $app->log;

  $app->routes->any($config->{path})->to(cb => sub {
    my $c = shift;
    my $payload = $c->req->body_params->param('payload');
    my $status = '';

    if($payload) {
      $status = $self->_fork_and_reload(Mojo::JSON->new->decode($payload)) ? "ok\n" : "$!\n";
    }
    else {
      for my $name (keys %{ $self->{repositories} }) {
        $status .= "--- $name\n";
        $self->_run(
          { GIT_DIR => "$self->{repositories}{$name}{path}/.git" },
          $GIT => log => -3 => '--format=%s',
          sub { $status .= "$_[0]\n" },
        );
        $status .= "\n";
      }
    }

    $c->render_text($status || "no repositories\n");
  });
}

sub _fork_and_reload {
  my($self, $payload) = @_;
  my $manager_pid = getppid;
  my $pid;

  $SIG{CHLD} = 'IGNORE';
  $pid = fork;

  return 1 if $pid;
  return 0 if !defined $pid;
  $self->_reload($manager_pid, $payload);
  exit;
}

sub _reload {
  my($self, $pid, $payload) = @_;
  my $log = $self->{log};
  my $branch = $payload->{ref} || '/ref';
  my $name = $payload->{repository}{name} || '/repository/name';
  my $sha1 = $payload->{head_commit}{id} || '/head_commit/id';
  my $config = $self->{repositories}{$name};

  $branch =~ s!refs/heads/!!;

  unless($config) {
    return $log->warn("Could not find repository config from $name");
  }
  unless($config->{branch} eq $branch) {
    return $log->debug("Skip branch $branch (not $config->{branch})");
  }

  eval {
    $log->info("chdir $config->{path}");
    chdir $config->{path};
    $self->_run($GIT => remote => update => $config->{remote});
    $self->_run($GIT => log => '--format=%H', '-n1', "$config->{remote}/$branch", sub {
      return $log->error("Invalid commit: $_[0] ne $sha1") unless $_[0] eq $sha1;
      $self->_run($GIT => checkout => -f => -B => toadfarm_reload_branch => "$config->{remote}/$branch");
      $self->_run(kill => -USR2 => $pid);
    });
    1;
  } or do {
    $log->error($@);
  };
}

sub _run {
  my($self, @cmd) = @_;
  my $env = ref @cmd[0] eq 'HASH' ? shift @cmd : {};
  my $cb = ref $cmd[-1] eq 'CODE' ? pop @cmd : sub { $self->{log}->info("<<< $_[0]") };
  my @res;

  local %ENV = %ENV;
  $ENV{$_} = $env->{$_} for keys %$env;
  $env = join ', ', map { "$_=$env->{$_}" } sort keys %$env;
  $env = "[$env] " if $env;

  # TODO:
  $self->{log}->info("${env}run(@cmd)");
  open my $CMD, '-|', @cmd or die "@cmd: $!";
  while(<$CMD>) {
    chomp;
    push @res, $cb->($_);
  }
}

sub _valid_config {
  my($self, $config) = @_;
  my $repositories = $config->{repositories};

  if(!$config->{path}) {
    $self->{log}->error('Abort loading Reload: "path" missing in config');
    return;
  }
  if(ref $repositories ne 'HASH' or !%$repositories) {
    $self->{log}->error('Abort loading Reload: "repositories" missing in config');
    return;
  }

  while(my($name, $config) = each %$repositories) {
    $config->{remote} ||= 'origin';
    for my $key (qw/ path branch /) {
      next if $config->{$key};
      $self->{log}->error(qq[Abort loading Reload: "repositories -> $name -> $key" missing in config]);
      return;
    }
  }

  $self->{repositories} = $repositories;
}

=head1 AUTHOR

Jan Henning Thorsen - C<jhthorsen@cpan.org>

=cut

1;