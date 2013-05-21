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
        repositories => [
          {
            name => 'cool-repo',
            branch => 'some-branch',
            path => '/path/to/cool-repo',
            remote => 'whatever', # defaults to "origin"
          },
        ],
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
use Mojo::Util;

my $JSON = Mojo::JSON->new;
our $GIT = $ENV{GIT_EXE} || 'git';

=head1 METHODS

=head2 register

  $self->register($app, \%config);

See L</SYNOPSIS> for C<%config> parameters.

=cut

sub register {
  my($self, $app, $config) = @_;
  my $t0 = localtime;

  $self->{log} = $app->log;
  $self->_valid_config($config) or return;

  $app->routes->any($config->{path})->to(cb => sub {
    my $c = shift;
    my $payload = $c->req->body_params->param('payload');
    my $status = "Started: $t0\n\n";
    my $args;

    if($payload) {
      $args = $JSON->decode(Mojo::Util::encode('UTF-8', $payload));
      $status = $self->_fork_and_reload($args) ? "ok\n" : "nok\n";
    }
    else {
      for my $config (@{ $self->{repositories} }) {
        $status .= "--- $config->{name}/$config->{branch}\n";
        $self->_run(
          { GIT_DIR => "$config->{path}/.git" },
          $GIT => log => -3 => '--format=%s',
          sub { $status .= "$_[0]\n" },
        );
        $status .= "\n";
      }
    }

    $c->render(text => $status, format => 'text');
  });
}

sub _fork_and_reload {
  my($self, $payload) = @_;
  my $manager_pid = getppid;
  my $branch = $payload->{ref};
  my $name = $payload->{repository}{name};
  my $sha1 = $payload->{head_commit}{id};
  my $refreshed = 0;
  my $pid;

  unless($branch and $name and $sha1) {
    $self->{log}->warn("Skip reload on bad payload: " .$JSON->encode($payload));
    return;
  }

  $SIG{CHLD} = 'IGNORE';
  $pid = fork;

  return 1 if $pid;
  return 0 if !defined $pid;

  # child process
  $branch =~ s!refs/heads/!!;

  for my $config (@{ $self->{repositories} }) {
    $config->{name} eq $name or next;
    $config->{branch} eq $branch or next;

    eval {
      $self->{log}->info("Reloading repo $name, branch $branch");
      $self->_refresh_repo($config, $sha1);
      ++$refreshed;
    } or do {
      $self->{log}->error($@);
    };
  }

  if($refreshed) {
    $self->_run(kill => -USR2 => $manager_pid)
  }
  else {
    $self->{log}->warn("Skip reload on name=$name and branch=$branch");
  }

  exit 0;
}

sub _refresh_repo {
  my($self, $config, $sha1) = @_;

  chdir $config->{path};
  $self->_run($GIT => remote => update => $config->{remote});
  $self->_run($GIT => log => '--format=%H', '-n1', "$config->{remote}/$config->{branch}", sub {
    return $self->{log}->error("Invalid commit: $_[0] ne $sha1") unless $_[0] eq $sha1;
    $self->_run($GIT => checkout => -f => -B => toadfarm_reload_branch => "$config->{remote}/$config->{branch}");
  });
}

sub _run {
  my($self, @cmd) = @_;
  my $env = ref $cmd[0] eq 'HASH' ? shift @cmd : {};
  my $cb = ref $cmd[-1] eq 'CODE' ? pop @cmd : sub { $self->{log}->info("<<< $_[0]") };
  my @res;

  local %ENV = %ENV;
  $ENV{$_} = $env->{$_} for keys %$env;
  $env = join ', ', map { "$_=$env->{$_}" } sort keys %$env;
  $env = "[$env] " if $env;

  # TODO:
  $self->{log}->debug("${env}run(@cmd)");
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
  if(ref $repositories eq 'HASH') {
    $repositories = [
      map {
        $repositories->{$_}{name} = $_;
        $repositories->{$_};
      } keys %$repositories
    ];
  }
  if(ref $repositories ne 'ARRAY' or !@$repositories) {
    $self->{log}->error('Abort loading Reload: "repositories" missing in config');
    return;
  }

  for my $config (@$repositories) {
    $config->{remote} ||= 'origin';
    for my $key (qw/ path branch /) {
      next if $config->{$key};
      $self->{log}->error(qq[Abort loading Reload: "repositories -> $config->{name} -> $key" missing in config]);
      return;
    }
  }

  $self->{repositories} = $repositories;
}

=head1 AUTHOR

Jan Henning Thorsen - C<jhthorsen@cpan.org>

=cut

1;
