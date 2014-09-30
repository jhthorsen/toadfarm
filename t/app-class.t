use Mojo::Base -strict;
use Test::More;
use Test::Mojo;

$ENV{MOJO_CONFIG} = 't/app-class.conf';
my $t = Test::Mojo->new('Toadfarm');

$t->get_ok('/')->status_is(404);
$t->get_ok('/dummy', {Host => 'te.st'})->status_is(200)->content_is("Dummy\n");
$t->get_ok('/dummy', {Host => 'whatever.te.st'})->status_is(200)->content_is("Dummy\n");

done_testing;
