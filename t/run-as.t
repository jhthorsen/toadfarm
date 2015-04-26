BEGIN { $ENV{TOADFARM_ACTION} = 'test' }
use Mojo::Base -strict;
use Test::More;
use Toadfarm -init;

my $username = 'www-data';
my $uid      = getpwnam 'www-data';

plan skip_all => 'www-data user does not exist' unless $uid;
diag "uid=$>";

if (eval { run_as $username }) {
  is run_as($username), 1, 'run_as';
  is $ENV{USER}, $username, $username;
}
else {
  like $@, qr{Could not run.*sudo}, 'could not run';
}

done_testing;
