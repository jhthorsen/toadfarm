use Mojo::Base -strict;
use Mojo::Util 'spurt';
use Test::More;

no warnings qw( once redefine );
my ($exit, $sleep, $quit);
*CORE::GLOBAL::sleep = sub { $sleep++ };

$SIG{QUIT} = sub { $quit++ };

require Toadfarm::Command::stop;
*Toadfarm::Command::stop::_exit = sub { $exit = $_[1]; die "$_[0]\n"; };
my $cmd = Toadfarm::Command::stop->new;

eval { $cmd->run };
like $@, qr{pid_file is not set}, 'pid_file is not set';

{
  use Toadfarm -dsl;
  start;
  $cmd->app(app);
}

eval { $cmd->run };
like $@, qr{not running}, 'not running';

spurt $$ => app->config->{hypnotoad}{pid_file};
eval { $cmd->run };
like $@,   qr{failed to stop}, 'failed to stop';
is $quit,  1,                  'signal sent';
is $sleep, 25,                 'slept';

$SIG{QUIT} = sub { unlink app->config->{hypnotoad}{pid_file} };
eval { $cmd->run };
like $@, qr{server stopped}, 'server stopped';

done_testing;

END {
  eval { app() } and unlink app->config->{hypnotoad}{pid_file};
}
