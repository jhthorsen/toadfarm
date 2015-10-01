use Mojo::Base -strict;
use Test::More;
use File::Temp;
use IO::Handle;

plan skip_all => 'Cannot run as root' if $< == 0 or $> == 0;

my $temp = File::Temp->new;
my $path = $temp->filename;
my ($exit, @seek);

print $temp "# some log line\n";

no warnings qw( once redefine );
*CORE::GLOBAL::exec = sub { die "@_" };
*CORE::GLOBAL::seek = sub { @seek = @_; CORE::seek($_[0], $_[1], $_[2]); print $temp "# xyz\n" };
*CORE::GLOBAL::tell = sub { die 'tell' };
require Toadfarm::Command::tail;
*Toadfarm::Command::start::_exit = sub { $exit = $_[2]; die "$_[1]\n"; };

my $cmd = Toadfarm::Command::tail->new;

$cmd->app->log->path(undef);
eval { $cmd->run };
like $@, qr{Unknown log file}, 'unknown log file';
is $exit, 2, 'no such file or directory';

$cmd->app->log->path($path);
eval { $cmd->run(qw( -n 10 )); };
like $@, qr{^tail -n 10 $path}, 'tail started';

$temp->autoflush(1);
eval { $cmd->run; };
like $@, qr{^tell}, 'tail -f';
is $seek[1], 16, 'seek';

done_testing;
