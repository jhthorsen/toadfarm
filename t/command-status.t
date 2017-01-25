use Mojo::Base -strict;
use Test::More;

plan skip_all => 'Cannot run as root' if $< == 0 or $> == 0;

$ENV{TOADFARM_NO_EXIT} = 1;
require Toadfarm::Command::status;
my $cmd = Toadfarm::Command::status->new;

like $cmd->run, qr{has invalid config}, 'has invalid config';
is int($!), 4, 'exit=4';

{
  use Toadfarm -init;
  start;
  $cmd->app(app);
}

like $cmd->run, qr{No PID file}, 'No PID file';
is int($!), 3, 'exit=3';

my $pid_file = $cmd->app->config->{hypnotoad}{pid_file};

if (open my $PID, '>', $pid_file) {
  print $PID "$$\n";
  close $PID;

  like $cmd->run, qr{is running}, 'is running';
  is int($!), 0, 'exit=0';

  my $pid = fork or exit;    # make up a PID
  wait;                      # wait for fork to exit
  open my $PID, '>', $pid_file;
  print $PID "     $pid   \n";
  close $PID;
  like $cmd->run, qr{PID file exists}, 'PID file exists';
  is int($!), 1, 'exit=1';

  diag $cmd->app->config->{hypnotoad}{pid_file};
  unlink $cmd->app->config->{hypnotoad}{pid_file};
}

done_testing;
