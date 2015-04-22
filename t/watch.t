use Mojo::Base -strict;
use Test::More;
use Carp ();

$ENV{TOADFARM_SILENT}       = 1 unless $ENV{TEST_VERBOSE};
$ENV{TOADFARM_WATCH_CYCLES} = 2;
$ENV{HOME}                  = 't';

plan skip_all => 'Cannot run on Win32' if $^O =~ /win/i;
plan skip_all => 'Cannot read t/.toadfarm/script.conf' unless -r 't/.toadfarm/script.conf';

my (@system, $ret);
no warnings 'once';
*CORE::GLOBAL::system = sub { @system = @_; $ENV{STAY_ALIVE} or Carp::confess('system') };
*CORE::GLOBAL::exit   = sub { die 'exit' };
*CORE::GLOBAL::sleep  = sub {1};

{
  local $ENV{MOJO_APP_LOADER} = 1;
  do 'script/toadfarm' or die $@;
}

{
  local @ARGV = qw( script.conf -w 1 );
  eval { main::run() };
  like $@, qr{system}, 'system hypnotoad';
  is_deeply \@system, [hypnotoad => 'script/toadfarm'], 'hypnotoad script/toadfarm';
  like $ENV{MOJO_CONFIG}, qr{t/\.toadfarm/script\.conf$}, 'MOJO_CONFIG';
}

{
  local @ARGV = ('script.conf', -w => __FILE__);
  no warnings 'redefine';
  local *main::read_pid = sub {$$};
  eval { main::run() };
  like $@, qr{exit}, 'application is running';
}

done_testing;
