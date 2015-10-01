use Mojo::Base -strict;
use Test::More;
use File::Temp;
use IO::Handle;
use Time::HiRes 'ualarm';

plan skip_all => 'Cannot run as root' if $< == 0 or $> == 0;

my $temp = File::Temp->new;
my $path = $temp->filename;
my $exit;

print $temp "# some log line\n";

no warnings qw( once redefine );
*CORE::GLOBAL::exec = sub { die "@_" };
require Toadfarm::Command::tail;
*Toadfarm::Command::start::_exit = sub { $exit = $_[2]; die $_[1] || 'EXIT'; };

my $cmd = Toadfarm::Command::tail->new;

$cmd->app->log->path(undef);
eval { $cmd->run };
like $@, qr{Unknown log file}, 'unknown log file';
is $exit, 2, 'no such file or directory';

$cmd->app->log->path($path);
eval { $cmd->run(qw( -n 10 )); };
like $@, qr{^tail -n 10 $path}, 'tail started';

my $n = 0;
$SIG{ALRM} = sub {
  ualarm 100e3;
  return print $temp "# xyz\n" unless $n++;
  kill INT => $$;
};
$temp->autoflush(1);
ualarm 100e3;
$exit = 42;
eval { $cmd->run; };
like $@,  qr{^EXIT}, 'tail -f';
is $exit, undef,     'exit';

done_testing;
