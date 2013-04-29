use strict;
use warnings;
use Test::More;
use Test::Mojo;

eval { Test::Mojo->new('Toadfarm') };
is $@, "You need to set MOJO_CONFIG\n", "config is missing";

$ENV{MOJO_CONFIG} = 't/basic.conf';
my $t = Test::Mojo->new('Toadfarm');

$t->get_ok('/')->status_is(404);
$t->get_ok('/', { Host => 'te.st' })->status_is(200)->content_is('http://te.st/test/123');
$t->get_ok('/', { 'X-Request-Base' => '/yikes' })->status_is(200)->content_like(qr{:\d+/test/123});

done_testing;
