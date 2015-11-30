use Mojo::Base -strict;
use Mojo::Util 'spurt';
use Test::More;

plan skip_all => 'Cannot run as root' if $< == 0 or $> == 0;

$ENV{TOADFARM_NO_EXIT} = 1;
no warnings qw( once redefine );
my ($exit, $sleep, @system);
*CORE::GLOBAL::system = sub { @system = @_; };
*CORE::GLOBAL::sleep = sub { $sleep++ };

require Toadfarm::Command::start;
my $cmd = Toadfarm::Command::start->new;

plan skip_all => $@ unless eval { $cmd->_hypnotoad };

eval { $cmd->run };
like $@, qr{pid_file is not set}, 'pid_file is not set';

{
  use Toadfarm -init;
  start;
  $cmd->app(app);
}

$? = 256;    # mock system() return value
like $cmd->run, qr{failed to start\. \(1\)$}, 'failed to start. (1)';

$? = 0;      # mock system() return value
like $cmd->run, qr{failed to start\.$}, 'failed to start';
is $sleep, 5, 'slept';
ok -e $system[0], 'found hypnotoad';
is $system[1], $0, 'hypnotoad $0';

spurt $$ => app->config->{hypnotoad}{pid_file};
$? = 0;      # mock system() return value
like $cmd->run, qr{ \($$\) already running.}, 'already running';

done_testing;

END {
  eval { app() } and unlink app->config->{hypnotoad}{pid_file};
}
