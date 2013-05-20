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

=head1 METHODS

=head2 register

Register an "around_dispatch" hook which will log the request.

=cut

sub register {
  my($self, $app, $config) = @_;
  my $log = $app->log;

  $app->hook(around_dispatch => sub {
    my($next, $c) = @_;

    $next->();

    $log->info(
      sprintf "%s %s %s %s",
      $c->tx->remote_address,
      $c->req->method,
      $c->req->url->to_abs,
      $c->res->code || 200,
    );
  });
}

=head1 AUTHOR

Jan Henning Thorsen - C<jhthorsen@cpan.org>

=cut

1;
