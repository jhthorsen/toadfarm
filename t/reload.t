use strict;
use warnings;
use Test::More;
use Test::Mojo;
use Cwd;

*Toadfarm::Plugin::Reload::getppid = sub {
  $$;
};

plan skip_all => $^O unless $^O =~ /linux/i;
plan skip_all => 'Started from wrong directory' unless -x 't/bin/git';

my($t, $USR2);

$ENV{PATH} = "t/bin:$ENV{PATH}";
$ENV{PATH} = join ':', 't/bin', $ENV{PATH};
$ENV{MOJO_CONFIG} = 't/reload.conf';
$SIG{USR2} = sub { $USR2++; Mojo::IOLoop->stop; };

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
is $USR2, 1, 'receive USR2 signal';

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