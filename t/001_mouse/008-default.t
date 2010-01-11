#!/usr/bin/env perl
use strict;
use warnings;
use Test::More tests => 36;
use Test::Mouse;

do {
    package Class;
    use Mouse;

    has 'x' => (
        is      => 'rw',
        default => 10,
    );

    has 'y' => (
        is      => 'rw',
        default => sub{ 20 },
    );

    has 'z' => (
        is => 'rw',
    );
};

with_immutable(sub{
    my $object = Class->new;
    is($object->x, 10, "attribute has a default of 10");
    is($object->y, 20, "attribute has a default of 20");
    is($object->z, undef, "attribute has no default");

    is($object->x(5), 5, "setting a new value");
    is($object->y(25), 25, "setting a new value");
    is($object->z(125), 125, "setting a new value");

    is($object->x, 5, "setting a new value does not trigger default");
    is($object->y, 25, "setting a new value does not trigger default");
    is($object->z, 125, "setting a new value does not trigger default");

    my $object2 = Class->new(x => 50);
    is($object2->x, 50, "attribute was initialized to 50");
    is($object2->y, 20, "attribute has a default of 20");
    is($object2->z, undef, "attribute has no default");

    is($object2->x(5), 5, "setting a new value");
    is($object2->y(25), 25, "setting a new value");
    is($object2->z(125), 125, "setting a new value");

    is($object2->x, 5, "setting a new value does not trigger default");
    is($object2->y, 25, "setting a new value does not trigger default");
    is($object2->z, 125, "setting a new value does not trigger default");

}, qw(Class));
