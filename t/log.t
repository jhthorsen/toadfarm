use strict;
use warnings;
use Test::More;
use Test::Mojo;

plan skip_all => 'PWD need to be set' unless $ENV{PWD} and -w "$ENV{PWD}/t";
plan tests => 8;

my $log_file = "$ENV{PWD}/t/log.log";

$ENV{MOJO_CONFIG} = 't/log.conf';
$ENV{MOJO_LOG_LEVEL} = 'debug';
unlink $log_file;
my $t = Test::Mojo->new('Toadfarm');

$t->app->routes->get('/with/identity' => sub {
  my $c = shift;
  $c->tx->req->env->{identity} = 'user1';
  $c->render(text => '123');
});

$t->get_ok('/yikes')->status_is(404);
$t->get_ok('/with/identity')->status_is(200);

ok -e $log_file, 'log file was created';
ok -s $log_file > 400, 'log file was written to';

open my $FH, '<', $log_file;
while(<$FH>) {
  diag $_ if $ENV{HARNESS_IS_VERBOSE};
  ok 1, 'got access log line' if m!info\W+\S+ GET http:.*?:\d+/yikes 404 [\d.]+s$!;
  ok 1, 'got access log line with identity' if m!info\W+user1 GET http:.*?:\d+/with/identity 200 [\d.]+s$!;
}

unlink $log_file unless $ENV{KEEP_LOG_FILE};
