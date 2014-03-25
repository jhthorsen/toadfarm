use strict;
use warnings;
use Test::More;
use Test::Mojo;
use Toadfarm;

my @rules;

{
  no warnings 'redefine';
  my $skip_if = \&Toadfarm::_skip_if;
  *Toadfarm::_skip_if = sub {
    my @r = $skip_if->(@_);
    push @rules, @r;
    return @r;
  };
}

$ENV{MOJO_CONFIG} = 't/rules.conf';
my $t = Test::Mojo->new('Toadfarm');

is_deeply(
  \@rules,
  [
    "return 0 unless +(\$_[1]->tx->remote_address || '') eq '10.10.10.10';",
    "return 0 unless +(\$_[1]->tx->remote_port || '') =~ /(?^:8000)/;",
    "return 0 unless +(\$h->header('Host') || '') eq 'te.st';",
    "return 0 unless +(\$h->header('X-Request-Base') || '') eq 'http:/domain.com/foo';",
  ],
  'got correct rules',
);

done_testing;
