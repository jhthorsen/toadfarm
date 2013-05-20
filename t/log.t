use strict;
use warnings;
use Test::More;
use Test::Mojo;

plan skip_all => 'PWD need to be set' unless $ENV{PWD} and -w "$ENV{PWD}/t";
plan tests => 5;

my $log_file = "$ENV{PWD}/t/log.log";

$ENV{MOJO_CONFIG} = 't/log.conf';
$ENV{MOJO_LOG_LEVEL} = 'debug';
unlink $log_file;
my $t = Test::Mojo->new('Toadfarm');

$t->get_ok('/yikes')->status_is(404);

ok -e $log_file, 'log file was created';
ok -s $log_file > 400, 'log file was written to';

open my $FH, '<', $log_file;
while(<$FH>) {
  ok 1, 'got access log line' if /info.*?GET http:.*?yikes/;
}

unlink $log_file unless $ENV{KEEP_LOG_FILE};
