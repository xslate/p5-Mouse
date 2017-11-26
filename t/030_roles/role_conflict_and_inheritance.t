use strict;
use warnings;
use Test::More;

{
    package Role::Foo1;
    use Mouse::Role;
    sub foo { 'foo1' }
}

{
    package Role::Foo2;
    use Mouse::Role;
    sub foo { 'foo2' }
}

{
    package BarSuper;
    use Mouse;
    sub foo { 'foo3' }
}

my @warn;
{
    package BarSub;
    use Mouse;
    extends 'BarSuper';
    local $SIG{__WARN__} = sub { push @warn, @_ };
    with 'Role::Foo1', 'Role::Foo2';
}

like $warn[0], qr/\QDue to a method name conflict in roles 'Role::Foo1' and 'Role::Foo2', the behavior of method 'foo' might be incompatible with Moose, check out BarSub/;

is(BarSub->new->foo, "foo3");

done_testing;
