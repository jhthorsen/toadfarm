use strict;
use warnings;
use Test::More;
use Test::Mojo;

$ENV{MOJO_CONFIG} = 't/basic.conf';
my $t = Test::Mojo->new('Toadfarm');

is_deeply $t->app->secrets, ['super-secret'], 'secrets are set';

$t->get_ok('/')
  ->status_is(404);

$t->get_ok('/', { Host => 'te.st' })
  ->status_is(200)
  ->content_is('http://te.st/test/123');

$t->get_ok('/', { 'X-Request-Base' => 'http://localhost:1234/yikes' })
  ->status_is(200)
  ->content_is('http://localhost:1234/yikes/test/123');

$t->get_ok('/info')
  ->status_is(200)
  ->content_is('["yikes"]');

$t->get_ok('/config.json', { 'X-Request-Base' => 'http://localhost:1234/yikes' })
  ->status_is(200)
  ->json_is('/foo', 123)
  ->json_has('/plugins', 'inherit toadfarm config')
  ->json_has('/apps')
  ->json_is('/apps/1/Host', 'te.st')
  ;

done_testing;
