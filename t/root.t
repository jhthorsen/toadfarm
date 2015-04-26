use Mojo::Base -strict;
use Mojo::JSON 'j';
use Mojo::Server::Daemon;
use Test::More;

$ENV{TEST_ORIGINAL_USER} = j {user => $ENV{USER}, uid => [$<, $>], gid => [$(, $)]} if $> != 0;
plan skip_all => 'TEST_RUN_SUDO=1' unless $ENV{TEST_RUN_SUDO};
exec qw( sudo -n -E ), $^X, -I => $INC[0], $0, @ARGV if $> != 0;

my $original = j($ENV{TEST_ORIGINAL_USER} || '{}');
plan skip_all => "user is missing in TEST_ORIGINAL_USER=$ENV{TEST_ORIGINAL_USER}"
  unless my $user = delete $original->{user};

my $daemon = Mojo::Server::Daemon->new({listen => ['http://127.0.0.1'], silent => 1, group => $user, user => $user});
$daemon->setuidgid->start;
$daemon->app->routes->children([]);
$daemon->app->routes->get('/' => sub { shift->render(json => {uid => [$<, $>], gid => [$(, $)]}) });
my $port   = Mojo::IOLoop->acceptor($daemon->acceptors->[0])->port;
my $buffer = '';
Mojo::IOLoop->client(
  {port => $port} => sub {
    my ($loop, $err, $stream) = @_;
    $stream->on(read => sub { $buffer .= $_[1]; Mojo::IOLoop->stop if $buffer =~ m/\}/ });
    $stream->write("GET / HTTP/1.1\x0d\x0a\x0d\x0a");
  }
);

Mojo::IOLoop->start;
$buffer =~ s!.*\x0d\x0a!!s;
is_deeply(j($buffer), $original) or diag $buffer;

done_testing;
