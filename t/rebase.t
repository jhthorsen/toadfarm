use strict;
use warnings;
use Test::More;
use Test::Mojo;

plan skip_all => $^O unless $^O =~ /linux/i;

my($t, @exec);

$ENV{PATH} = join ':', 't/bin', $ENV{PATH};
$ENV{MOJO_CONFIG} = 't/rebase.conf';
$t = Test::Mojo->new('Toadfarm');

$t->get_ok('/')
  ->status_is(404);

$t->get_ok('/bad-path')
  ->status_is(200)
  ->json_has('/start');

$t->post_ok('/bad-path', {}, form => { payload => '' })->status_is(400);

local $0 = 'restarter.sh';
$t->post_ok('/bad-path', {}, form => { payload => payload('refs/heads/oh-no') })
  ->status_is(200)
  ->json_is('/rebasing', 1);

open my $LOG, '<', 't/bin/restarter.log' or die $!;
is <$LOG>, "HYPNOTOAD_PID=\n", "HYPNOTOAD_PID";
is <$LOG>, "HYPNOTOAD_REV=\n", "HYPNOTOAD_REV";
is <$LOG>, "rebase oh-no\n", "rebase oh-no";

unlink 't/bin/restarter.log';
done_testing;

sub payload {
  Mojo::JSON->new->encode({ ref => shift, anything => 42 })
}