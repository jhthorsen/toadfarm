use Mojo::Base -strict;
use Mojo::Util 'spurt';
use Test::More;

plan skip_all => 'Cannot run as root' if $< == 0 or $> == 0;

$ENV{TOADFARM_NO_EXIT} = 1;
no warnings qw( once redefine );
my ($exit, $sleep, @system);
*CORE::GLOBAL::system = sub { @system = @_; };

require Toadfarm::Command::reload;
my $cmd = Toadfarm::Command::reload->new;

plan skip_all => $@ unless eval { $cmd->_hypnotoad };

{
  use Toadfarm -init;
  start;
  $cmd->app(app);
}

$? = 256;    # mock system() return value
like $cmd->run, qr{failed to reload\. \(1\)$}, 'failed to reload. (1)';
is int($!), 1, 'exit 1';
like "@system", qr{hypnotoad \S*command-reload\.t$}, 'system';

$? = 0;      # mock system() return value
is $cmd->run, '', 'reloaded';
is int($!), 0, 'exit 0';

done_testing;
