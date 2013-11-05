use strict;
use warnings;
use Test::More;

{
    package Role::Foo1;
    use Mouse::Role;
    sub foo { 'foo1' }

    package Role::Foo2;
    use Mouse::Role;
    sub foo { 'foo2' }

    package BarSuper;
    use Mouse;
    sub foo { 'foo3' }

    package BarSub;
    use Mouse;
    extends 'BarSuper';
    with 'Role::Foo1', 'Role::Foo2';
}

is(BarSub->new->foo, "foo3");

done_testing;
