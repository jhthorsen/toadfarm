use Mojo::Base -strict;
use Test::More;

plan skip_all => 'Ubic is not installed'   unless eval 'use Ubic; 1';
plan skip_all => 'Need to set TEST_UBIC=1' unless $ENV{TEST_UBIC};

my (@system, @kill);

{
  $ENV{$_} = 't/ubic' for qw( UBIC_SERVICE_DIR UBIC_DIR UBIC_DEFAULT_USER );
  $ENV{PATH} = "script:$ENV{PATH}";
  *Ubic::Service::Toadfarm::system = sub { @system = @_ };
  *Ubic::Service::Toadfarm::kill   = sub { @kill   = @_ };
  require Ubic::Service::Toadfarm;
}

{
  eval { Ubic::Service::Toadfarm->new };
  like $@, qr{hypnotoad => listen}, 'hypnotoad => listen missing';
}

delete $ENV{TEST123};

my $log_file = 't/ubic/toadfarm.log';
my $service  = Ubic::Service::Toadfarm->new(
  log       => {file    => $log_file,},
  hypnotoad => {listen  => ['http://*:1345'], status_resource => '/status123',},
  env       => {TEST123 => 123,},
);

{
  mkdir 't/ubic';
  mkdir 't/ubic/tmp';
  unlink 't/ubic/tmp/test123.conf';
  $service->{name} = 'test123';
  $service->start_impl;
  is $ENV{TEST123}, undef, 'environment localized';
  like "@system", qr{hypnotoad\s*script/toadfarm}, 'system hypnotoad toadfarm';
  my $config = do 't/ubic/tmp/test123.conf';
  is_deeply(
    $config,
    {
      name => 'test123',
      env  => {TEST123 => 123,},
      hypnotoad =>
        {listen => ['http://*:1345'], pid_file => 't/ubic/tmp/test123.pid', status_resource => '/status123',},
      log => {file => 't/ubic/toadfarm.log'},
    },
    'generated config',
  );
}

{
  my $url;
  my $test123;
  like $service->status_impl, qr{running \(pid \d+, no response\)}, 'toadfarm not running';

  no warnings 'redefine';
  *Mojo::UserAgent::head = sub {
    my $tx = Mojo::Transaction->new;
    $url = $_[1];
    $tx->res->code(42);
    $test123 = $ENV{TEST123};
    $tx;
  };

  like $service->status_impl, qr/running \(pid \d+, status 42\)/, 'toadfarm is running';
  like $url, qr{/status123$}, 'correct status url';
  is $ENV{TEST123}, undef, 'environment does not leak';
  is $test123, 123, 'environment localized inside the function';
}

{
  unlink $service->_path_to_pid_file;
  is $service->stop, 'not running', 'toadfarm is not running';
  open my $FH, '>', $service->_path_to_pid_file;
  print $FH "... $$ garbage\n";
  close $FH;

  is $service->stop, 'stopped', 'toadfarm is not running';
  like "@kill", qr{TERM\s*$$}, 'sent TERM signal'
}

{
  is $service->reload, 'reloaded', 'reloaded';
  like "@kill", qr{USR2\s*$$}, 'sent USR2 signal'
}

done_testing;
