use v5.10;
use warnings;
use Test::More;
use Config::Reload;

my $c = Config::Reload->new( file => 't/data/valid.json' );

if ($^O =~ /bsd$/) { # CPANT repots error on BSD systems
    use Data::Dumper;
    diag Dumper($c->load);
    diag $c->error;
}
is_deeply $c->load, { foo => 'bar' }, 'valid JSON';

$c = Config::Reload->new( file => 't/data/invalid.json' );
is_deeply $c->load, { }, 'invalid JSON';
ok $c->error, 'error on load';

done_testing;
