use strict;
use warnings;
use Test::More;
use Test::Mojo;

$ENV{MOJO_CONFIG} = 't/custom-error.conf';
my $t = Test::Mojo->new('Toadfarm');

$t->get_ok('/')
  ->status_is(404)
  ->content_like(qr{^404444444440404040404040404});

$t->get_ok('/yay.txt')
  ->status_is(200)
  ->content_like(qr{^yay});

done_testing;
