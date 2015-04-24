use Mojo::Base -strict;
use Mojo::Util 'spurt';
use Test::More;

no warnings qw( once redefine );
my ($exit, $sleep, @system);
*CORE::GLOBAL::system = sub { @system = @_; };
*CORE::GLOBAL::sleep = sub { $sleep++ };

require Toadfarm::Command::start;
*Toadfarm::Command::start::_exit = sub { $exit = $_[1]; die "$_[0]\n"; };
my $cmd = Toadfarm::Command::start->new;

eval { $cmd->run };
like $@, qr{pid_file is not set}, 'pid_file is not set';

{
  use Toadfarm -dsl;
  start;
  $cmd->app(app);
}

$? = 256;
eval { $cmd->run };
like $@, qr{failed to start\. \(1\)$}, 'failed to start. (1)';

$? = 0;
eval { $cmd->run };
like $@, qr{failed to start\.$}, 'failed to start';
is $sleep, 5, 'slept';
is_deeply(\@system, ['hypnotoad', $0], 'system');

spurt $$ => app->config->{hypnotoad}{pid_file};
$? = 0;
eval { $cmd->run };
like $@, qr{already running $$}, 'already running';

done_testing;

END {
  eval { app() } and unlink app->config->{hypnotoad}{pid_file};
}
