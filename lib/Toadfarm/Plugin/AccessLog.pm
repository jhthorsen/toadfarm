package Toadfarm::Plugin::AccessLog;

=head1 NAME

Toadfarm::Plugin::AccessLog - Log requests

=head1 DESCRIPTION

This module will log the request with "info" log level. The log format
is subject for change. For now it is:

    $remote_address $http_method $url $status_code
    1.2.3.4 GET http://localhost/favicon.ico 200

=cut

use Mojo::Base 'Mojolicious::Plugin';
use Time::HiRes qw( gettimeofday tv_interval );

=head1 METHODS

=head2 register

Register an "around_dispatch" hook which will log the request.

=cut

sub register {
  my($self, $app, $config) = @_;
  my $log = $app->log;

  $app->hook(before_dispatch => sub {
    my $c = shift;

    $c->tx->req->env->{t0} = [gettimeofday];
    $c->tx->on(finish => sub {
      my $tx = shift;
      my $req = $tx->req;

      $log->info(
        sprintf '%s %s %s %s %.4fs',
        $req->env->{identity} || $tx->remote_address,
        $req->method,
        $req->url->to_abs->userinfo(''),
        $tx->res->code || '000',
        tv_interval($req->env->{t0}),
      );
    });
  });
}

=head1 AUTHOR

Jan Henning Thorsen - C<jhthorsen@cpan.org>

=cut

1;
