use strict;
use warnings;
use Test::More tests => 5;

{
    package ParentRole;
    use Mouse::Role;
    sub parent_method { 'parent_method' }
}

{
    package ChildRole;
    use Mouse::Role;

    with 'ParentRole';

    sub child_method { "role's" }
}

{
    package Class;
    use Mouse;
    with 'ChildRole';

    sub child_method { "class's" }
}

my $o = Class->new;

ok $o->does('ChildRole'), 'does ChildRole';
ok $o->does('ParentRole'), 'does ParentRole';
can_ok $o, qw(parent_method child_method);
is $o->parent_method, 'parent_method';
is $o->child_method,  "class's";

