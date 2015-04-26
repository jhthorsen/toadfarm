use Mojo::Base -strict;
use Test::More;
use Test::Mojo;
use Cwd;
use utf8;

plan skip_all => $^O unless $^O =~ /linux/i;
plan skip_all => 'Started from wrong directory' unless -x 't/bin/git';
plan skip_all => 'Git is required' unless -x '/usr/bin/git' and -d '.git';

my $PID         = $$;
my $LAST_COMMIT = qx{/usr/bin/git log --format=%H -n1 origin/master};
my ($t, $got_signal, $chdir);

chomp $LAST_COMMIT;

$ENV{PATH}        = "t/bin:$ENV{PATH}";
$ENV{MOJO_CONFIG} = 't/reload.conf';
$SIG{USR1}        = sub { $chdir++ };
$SIG{USR2}        = sub { $got_signal++; Mojo::IOLoop->stop; };

{
  use Toadfarm -init;

  no warnings qw( redefine once );
  *Toadfarm::Plugin::Reload::getppid = sub {$PID};
  *Toadfarm::Plugin::Reload::chdir = sub {
    CORE::chdir($_[0]) or return;
    kill 'USR1', $PID;
    1;
  };

  $ENV{TOADFARM_ACTION} = 'load';
  plugin "Toadfarm::Plugin::Reload" => {
    path         => '/super/private/secret/path',
    repositories => {toadfarm => {branch => 'master', path => $ENV{PWD}, remote => 'origin'}}
  };
  start;

  $t = Test::Mojo->new(app);
}

$ENV{TOADFARM_GITHUB_DELAY} = 0;

{
  diag 'Reloading';
  $t->post_ok('/super/private/secret/path', {}, payload('refs/heads/master'))->status_is(200)->content_is("ok\n");

  Mojo::IOLoop->timer(
    2,
    sub {
      ok 0, 'possible race condition';
      Mojo::IOLoop->stop;
    }
  );

  Mojo::IOLoop->start;
  is $chdir,      1, 'chdir before git commands';
  is $got_signal, 1, 'receive USR2 signal';
}

{
  diag 'Skip reloading';
  $t->post_ok('/super/private/secret/path', {}, payload('refs/heads/foo/bar'))->status_is(200)->content_is("ok\n");

  Mojo::IOLoop->timer(0.5, sub { Mojo::IOLoop->stop; });
  Mojo::IOLoop->start;
  is $chdir,      1, 'chdir before git commands';
  is $got_signal, 1, 'receive USR2 signal';
}

{
  diag 'Bad payload';
  $t->post_ok('/super/private/secret/path', {}, payload(''))->status_is(200)->content_is("nok\n");
}

{
  diag 'Status';
  $t->get_ok('/super/private/secret/path')->status_is(200)->content_like(qr{^--- toadfarm/master\n}m)
    ->content_like(qr{^Started: \w+}m)->content_like(qr{\n\n$}s);
}

#=============================================================================
done_testing;

sub payload {
  my $ref = shift;
  return <<"  JSON";
{
   "repository" : {
      "name" : "toadfarm"
   },
   "ref" : "$ref",
   "head_commit" : {
      "id" : "$LAST_COMMIT",
      "author" : {
        "email" : "markus\@vesoen.com",
        "name" : "Markus Vesøen",
        "username" : "markusvesoen"
      }
   }
}
  JSON
}
