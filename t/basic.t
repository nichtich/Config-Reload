use v5.14.1;
use warnings;
use Test::More;
use Config::Reload;

my $c = Config::Reload->new( file => 't/data/valid.json' );

is_deeply $c->load, { foo => 'bar' }, 'valid JSON';

$c = Config::Reload->new( file => 't/data/invalid.json' );
is_deeply $c->load, { }, 'invalid JSON';
ok $c->error, 'error on load';

done_testing;
