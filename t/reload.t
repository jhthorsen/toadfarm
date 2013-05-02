use strict;
use warnings;
use Test::More;
use Test::Mojo;
use Cwd;

plan skip_all => $^O unless $^O =~ /linux/i;
plan skip_all => 'Started from wrong directory' unless -x 't/bin/git';
plan skip_all => 'Git is required' unless -x '/usr/bin/git' and -d '.git';

my $PID = $$;
my $LAST_COMMIT = qx{/usr/bin/git log --format=%H -n1 origin/master};
my($t, $got_signal, $chdir);

chomp $LAST_COMMIT;

*Toadfarm::Plugin::Reload::getppid = sub { $PID };
*Toadfarm::Plugin::Reload::chdir = sub { kill 'USR1', $PID; CORE::chdir(@_) };

$ENV{PATH} = "t/bin:$ENV{PATH}";
$ENV{PATH} = join ':', 't/bin', $ENV{PATH};
$ENV{MOJO_CONFIG} = 't/reload.conf';
$SIG{USR1} = sub { $chdir++ };
$SIG{USR2} = sub { $got_signal++; Mojo::IOLoop->stop; };

$t = Test::Mojo->new('Toadfarm');

$t->post_ok('/bad-path', {}, form => { payload => payload('refs/heads/master') })
  ->status_is(200)
  ->content_is("ok\n");

Mojo::IOLoop->timer(2, sub {
  ok 0, 'possible race condition';
  Mojo::IOLoop->stop;
});

Mojo::IOLoop->start;
is $chdir, 1, 'chdir before git commands';
is $got_signal, 1, 'receive USR2 signal';

$t->get_ok('/bad-path')
  ->status_is(200)
  ->content_like(qr{^--- toadfarm\n})
  ->content_like(qr{\n\n$});

#=============================================================================
done_testing;

sub payload {
  Mojo::JSON->new->encode({
    ref => shift,
    head_commit => {
      id => $LAST_COMMIT,
    },
    repository => {
      name => 'toadfarm',
    },
  })
}