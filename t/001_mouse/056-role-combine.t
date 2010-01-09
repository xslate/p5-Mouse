#!perl
use strict;
use warnings;
use Test::More tests => 2;
use Test::Exception;
{
    package RoleA;
    use Mouse::Role;

    sub foo { }
    sub bar { }
}
{
    package RoleB;
    use Mouse::Role;

    sub foo { }
    sub bar { }
}
{
    package Class;
    use Mouse;
    use Test::More;
    use Test::Exception;

    throws_ok {
        with qw(RoleA RoleB);
    } qr/Due to method name conflicts in roles 'RoleA' and 'RoleB', the methods 'bar' and 'foo' must be/;

    lives_ok {
        with RoleA => { -excludes => ['foo'] },
             RoleB => { -excludes => ['bar'] },
        ;
    };
}
