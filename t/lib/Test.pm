package t::lib::Test;
use Mojolicious::Lite;

get '/', sub {
    $_[0]->render_text($_[0]->url_for('/test/123')->to_abs);
};

app->start;
