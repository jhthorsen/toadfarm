use Mojo::Base -strict;
use Test::Mojo;
use Test::More;

$ENV{TOADFARM_ACTION} = 'load';
use Toadfarm::Starter;
app->config->{foo} = 1;    # should not override 123 below
logging {combined => 1, level => 'debug'};
mount 't::lib::Test';
plugin 't::lib::Plugin' => ['yikes'];
start ['http://*:5000'], proxy => 1;

my $t = Test::Mojo->new(app);

isa_ok($t->app, 'Mojolicious::Lite');
is $t->app->moniker, 'Test', 'moniker';
is $t->app->log->level, 'debug', 'log level';
like $t->app->secrets->[0], qr/^\w{32}$/, 'random secrets';
is_deeply $t->app->config->{hypnotoad}{listen}, ['http://*:5000'], 'listen';

#$t->get_ok('/')->status_is(200)->content_like(qr{/test/123$});

done_testing;
