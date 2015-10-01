use Mojo::Base -strict;
use Mojo::Util 'spurt';
use Test::More;
use File::Temp;
use IO::Handle;

plan skip_all => 'Cannot run as root' if $< == 0 or $> == 0;

my @print;

no warnings qw( once redefine );
require Toadfarm::Command::tail;
*Toadfarm::Command::tail::_exit = sub { die @_; };
*Toadfarm::Command::tail::_print = sub { shift; push @print, "@_" };
my $cmd  = Toadfarm::Command::tail->new;
my $temp = File::Temp->new;

$cmd->app->log->path($temp->filename);
$temp->autoflush(1);

print $temp "$_: some random message @{[rand]}\n" for 1 .. 5;
eval { $cmd->run; };
ok UNIVERSAL::isa($@, 'Toadfarm::Command::tail'), 'run() completed';
is @print, 5, 'log five lines back';

print $temp "$_: some random message @{[rand]}\n" for 10 .. 40;
eval { $cmd->run; };
ok UNIVERSAL::isa($@, 'Toadfarm::Command::tail'), 'run() completed';
is @print, 10, 'log ten lines back';

done_testing;
