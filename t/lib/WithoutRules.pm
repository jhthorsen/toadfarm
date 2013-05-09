package t::lib::WithoutRules;
use Mojolicious::Lite;

get '/', sub { $_[0]->render_text('ROOT') };
get '/other', sub { $_[0]->render_text('OTHER') };

app->start;
