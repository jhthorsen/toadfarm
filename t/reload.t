use strict;
use warnings;
use Test::More;
use Test::Mojo;
use Cwd;

plan skip_all => $^O unless $^O =~ /linux/i;
plan skip_all => 'Started from wrong directory' unless -x 't/bin/git';

my $pid = $$;
my($t, $got_signal, $chdir);

*Toadfarm::Plugin::Reload::getppid = sub { $pid };
*Toadfarm::Plugin::Reload::chdir = sub { kill 'USR1', $pid; CORE::chdir(@_) };

$ENV{PATH} = "t/bin:$ENV{PATH}";
$ENV{PATH} = join ':', 't/bin', $ENV{PATH};
$ENV{MOJO_CONFIG} = 't/reload.conf';
$SIG{USR1} = sub { $chdir++ };
$SIG{USR2} = sub { $got_signal++; Mojo::IOLoop->stop; };

$t = Test::Mojo->new('Toadfarm');

$t->get_ok('/bad-path')
  ->status_is(200)
  ->content_is(localtime($^T) ."\n");

$t->post_ok('/bad-path', {}, form => { payload => payload('refs/heads/master') })
  ->status_is(200)
  ->content_is(localtime($^T) ."\n");

Mojo::IOLoop->timer(2, sub {
  ok 0, 'possible race condition';
  Mojo::IOLoop->stop;
});

Mojo::IOLoop->start;
is $chdir, 1, 'chdir before git commands';
is $got_signal, 1, 'receive USR2 signal';

#=============================================================================
done_testing;

sub payload {
  Mojo::JSON->new->encode({
    ref => shift,
    head_commit => {
      id => "log --format=%H -n1 origin/master",
    },
    repository => {
      name => 'toadfarm',
    },
  })
}