#!/usr/bin/perl

use strict;
use warnings;

use Test::More tests => 10;
use Test::Exception;

BEGIN {
    use_ok('Mouse::Util::TypeConstraints');
    use_ok('Mouse::Meta::TypeConstraint::Parameterized');
}

my $r = Mouse::Util::TypeConstraints->get_type_constraint_registry;

# Array of Ints

my $array_of_ints = Mouse::Meta::TypeConstraint::Parameterized->new(
    name           => 'ArrayRef[Int]',
    parent         => find_type_constraint('ArrayRef'),
    type_parameter => find_type_constraint('Int'),
);
isa_ok($array_of_ints, 'Mouse::Meta::TypeConstraint::Parameterized');
isa_ok($array_of_ints, 'Mouse::Meta::TypeConstraint');

$r->add_type_constraint($array_of_ints);

is(find_type_constraint('ArrayRef[Int]'), $array_of_ints, '... found the type we just added');

# Hash of Ints

my $hash_of_ints = Mouse::Meta::TypeConstraint::Parameterized->new(
    name           => 'HashRef[Int]',
    parent         => find_type_constraint('HashRef'),
    type_parameter => find_type_constraint('Int'),
);
isa_ok($hash_of_ints, 'Mouse::Meta::TypeConstraint::Parameterized');
isa_ok($hash_of_ints, 'Mouse::Meta::TypeConstraint');

$r->add_type_constraint($hash_of_ints);

is(find_type_constraint('HashRef[Int]'), $hash_of_ints, '... found the type we just added');

## now attempt a coercion

{
    package Foo;
    use Mouse;
    use Mouse::Util::TypeConstraints;

    coerce 'ArrayRef[Int]'
        => from 'HashRef[Int]'
            => via { [ values %$_ ] };

    has 'bar' => (
        is     => 'ro',
        isa    => 'ArrayRef[Int]',
        coerce => 1,
    );

}

my $foo = Foo->new(bar => { one => 1, two => 2, three => 3 });
isa_ok($foo, 'Foo');

is_deeply([ sort @{$foo->bar} ], [ 1, 2, 3 ], '... our coercion worked!');


