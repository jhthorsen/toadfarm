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

$t->get_ok('/with/identity')->status_is(200);
$t->get_ok($t->tx->req->url->to_abs->userinfo('secret:user')->path('/yikes'))->status_is(404);

my $hostname = $t->tx->req->url->host;
my @log_line;

ok -e $log_file, 'log file was created';
ok -s $log_file > 400, 'log file was written to';

open my $FH, '<', $log_file;
while(<$FH>) {
  diag $_ if $ENV{HARNESS_IS_VERBOSE};
  push @log_line, $_ if m!info\W+\S+ GET http://$hostname:\d+/yikes 404 [\d.]+s$!;
  push @log_line, $_ if m!info\W+user1 GET http://$hostname:\d+/with/identity 200 [\d.]+s$!;
}

ok $log_line[0], 'got access log line with identity' or diag join "\n", @log_line;
ok $log_line[1], 'got access log line without userinfo' or diag join "\n", @log_line;

unlink $log_file unless $ENV{KEEP_LOG_FILE};
