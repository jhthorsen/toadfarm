use Mojo::Base -strict;
use Test::More;
use Test::Mojo;

plan skip_all => 'PWD need to be set' unless $ENV{PWD} and -w "$ENV{PWD}/t";
plan tests => 8;

my $log_file = "$ENV{PWD}/t/log.log";

$ENV{MOJO_CONFIG}    = 't/log.conf';
$ENV{MOJO_LOG_LEVEL} = 'debug';
unlink $log_file;
my $t = Test::Mojo->new('Toadfarm');

$t->app->routes->get(
  '/with/identity' => sub {
    my $c = shift;
    $c->tx->req->env->{identity} = 'user1';
    $c->render(text => '123');
  }
);

$t->get_ok('/with/identity')->status_is(200);
$t->get_ok($t->tx->req->url->to_abs->userinfo('secret:user')->path('/yikes'))->status_is(404);

my ($with, $without);

ok -e $log_file, 'log file was created';
ok -s $log_file > 400, 'log file was written to';

open my $FH, '<', $log_file;
while (<$FH>) {
  diag "$.: $_" if $ENV{HARNESS_IS_VERBOSE};

  #[info] 127.0.0.1 GET http://127.0.0.1:35902/yikes 404 0.0145s
  #[info] user1 GET http://127.0.0.1:35902/with/identity 200 0.0012s

  $without = $_ if m!info\W+\S+ GET http://[\w\.]+:\d+/yikes 404 [\d.]+s$!;
  $with    = $_ if m!info\W+user1 GET http://[\w\.]+:\d+/with/identity 200 [\d.]+s$!;
}

like $with,    qr{\buser1\b.*identity}, 'got access log line with identity';
like $without, qr{GET.*yikes},          'got access log line without userinfo';

unlink $log_file unless $ENV{KEEP_LOG_FILE};
