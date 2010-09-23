#!/usr/bin/perl

use strict;
use warnings;

use Test::More tests => 7;
use Test::Exception;

use Mouse::Util::TypeConstraints;

=pod

This tests demonstrates that Mouse will not override
a preexisting type constraint of the same name when
making constraints for a Mouse-class.

It also tests that an attribute which uses a 'Foo' for
it's isa option will get the subtype Foo, and not a
type representing the Foo moose class.

=cut

BEGIN {
    # create this subtype first (in BEGIN)
    subtype Foo
        => as 'Value'
        => where { $_ eq 'Foo' };
}

{ # now seee if Mouse will override it
    package Foo;
    use Mouse;
}

my $foo_constraint = find_type_constraint('Foo');
isa_ok($foo_constraint, 'Mouse::Meta::TypeConstraint');

is($foo_constraint->parent->name, 'Value', '... got the Value subtype for Foo');

ok($foo_constraint->check('Foo'), '... my constraint passed correctly');
ok(!$foo_constraint->check('Bar'), '... my constraint failed correctly');

{
    package Bar;
    use Mouse;

    has 'foo' => (is => 'rw', isa => 'Foo');
}

my $bar = Bar->new;
isa_ok($bar, 'Bar');

lives_ok {
    $bar->foo('Foo');
} '... checked the type constraint correctly';

dies_ok {
    $bar->foo(Foo->new);
} '... checked the type constraint correctly';



