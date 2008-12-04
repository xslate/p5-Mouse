use strict;
use warnings;
use Test::More;

plan skip_all => "Moose way 'with' function test" unless $ENV{MOUSE_DEVEL};
plan tests => 2;

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
    package Requires2;
    use Mouse::Role;
    requires 'bar';
}

{
    package Method2;
    use Mouse::Role;

    sub foo { 'yep' }
}


{
    package MyApp;
    use Mouse;
    with ('Requires2', 'Method2' => { alias => { foo => 'bar' } }, 'Requires', 'Method');
}

my $m = MyApp->new;
is $m->foo, 'ok';
is $m->bar, 'yep';

