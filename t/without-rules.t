use Mojo::Base -strict;
use Test::More;
use Test::Mojo;

plan skip_all => 'Started from wrong directory' unless -x 't/bin/git';

$ENV{PATH}        = "t/bin:$ENV{PATH}";
$ENV{MOJO_CONFIG} = 't/without-rules.conf';
my $t = Test::Mojo->new('Toadfarm');

$t->get_ok('/')->content_is('ROOT');
$t->get_ok('/other')->content_is('OTHER');
$t->get_ok('/reload')->content_like(qr{--- cool-repo});

done_testing;
