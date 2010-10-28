#!perl -w
use strict;
use Test::More;
{
    package Role;
    use Mouse::Role;

    has foo => (
        is       => 'bare',
        init_arg => undef,
    );

    package Class;
    use Mouse;
    with 'Role';

    has "+foo" => (
        default => 'bar',
    );

    ::ok( __PACKAGE__->meta->find_attribute_by_name('foo')->has_default );
}

my $foo = Class->meta->get_attribute('foo');
ok $foo;
is $foo->name, 'foo';
is $foo->init_arg, undef;
is $foo->default, 'bar';

done_testing;

