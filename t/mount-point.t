use strict;
use warnings;
use Test::More;
use Test::Mojo;

$ENV{MOJO_CONFIG} = 't/mount-point.conf';
my $t = Test::Mojo->new('Toadfarm');

$t->get_ok('/foo')->status_is(404);
$t->get_ok('/bar/url')->status_is(200)->content_like(qr{:\d+/bar/url$});
$t->get_ok('/url')->status_is(200)->content_like(qr{:\d+/url$});
$t->get_ok('/baz/url')->status_is(404);
$t->get_ok('/baz/url', { 'X-Foo' => 123 })->status_is(200)->content_like(qr{:\d+/baz/url$});

done_testing;
