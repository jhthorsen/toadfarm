use Mojo::Base -strict;
use Mojo::Util 'spurt';
use Test::More;

no warnings qw( once redefine );
my ($exit, $sleep, @system);
*CORE::GLOBAL::system = sub { @system = @_; };

require Toadfarm::Command::reload;
*Toadfarm::Command::reload::_exit = sub { $exit = $_[1]; die "$_[0]\n"; };
my $cmd = Toadfarm::Command::reload->new;

{
  use Toadfarm -dsl;
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
