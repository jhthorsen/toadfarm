use Mojo::Base -strict;
use Mojo::Util 'spurt';
use Test::More;

plan skip_all => 'Cannot run as root' if $< == 0 or $> == 0;

no warnings qw( once redefine );
my ($exit, $sleep, @system);
*CORE::GLOBAL::system = sub { @system = @_; };

require Toadfarm::Command::reload;
*Toadfarm::Command::reload::_exit = sub { $exit = $_[2]; die "$_[1]\n"; };
my $cmd = Toadfarm::Command::reload->new;

plan skip_all => $@ unless eval { $cmd->_hypnotoad };

{
  use Toadfarm -init;
  start;
  $cmd->app(app);
}

$? = 256;
eval { $cmd->run };
like $@, qr{failed to reload\. \(1\)$}, 'failed to reload. (1)';

$? = 0;
eval { $cmd->run };
$@ ||= '';
is $@, '', 'reloaded';

done_testing;
