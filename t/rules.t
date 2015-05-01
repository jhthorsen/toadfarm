use Mojo::Base -strict;
use Test::More;
use Test::Mojo;
use Toadfarm -init;

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

mount 't::lib::Test' => {
  'config'         => {bar => 123},
  'mount_point'    => '/foo',
  'remote_address' => '10.10.10.10',
  'remote_port'    => qr{8000},
  'Host'           => 'te.st',
  'X-Request-Base' => 'http:/domain.com/foo',
};
start;

my @match = (
  qr{return 0 unless \+\(\$h->header\('Host'\) \|\| ''\) eq 'te\.st';},
  qr{return 0 unless \+\(\$_\[1\]->tx->remote_port \|\| ''\) \=\~ \/\D*8000\D*\/;},
  qr{return 0 unless \+\(\$_\[1\]->tx->remote_address \|\| ''\) eq '10\.10\.10\.10';},
  qr{return 0 unless \+\(\$h->header\('X-Request-Base'\) \|\| ''\) eq 'http:\/domain\.com\/foo';},
);

for my $r (sort { length $a <=> length $b } @rules) {
  like $r, shift(@match), $r;
}

done_testing;
