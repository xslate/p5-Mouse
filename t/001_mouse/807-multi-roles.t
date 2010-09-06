use strict;
use warnings;
use Test::More tests => 3;

{
    package Requires;
    use Mouse::Role;
    requires 'foo';
}

{
    package Method;
    use Mouse::Role;

    sub foo { 'ok' }
}

{
    package Method2;
    use Mouse::Role;

    sub bar { 'yep' }
}

{
    package MyApp;
    use Mouse;
    with ('Requires', 'Method');
    with ('Method2' => { -alias => { bar => 'baz' } });
}

my $m = MyApp->new;
is $m->foo, 'ok';
is $m->bar, 'yep';
is $m->baz, 'yep';

