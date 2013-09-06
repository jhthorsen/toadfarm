package t::lib::Test;
use Mojolicious::Lite;

get '/' => sub {
  $_[0]->render(text => $_[0]->url_for('/test/123')->to_abs);
};

get '/config' => sub {
  $_[0]->render(json => $_[0]->app->config);
};

app->start;
