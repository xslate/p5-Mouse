#!/usr/bin/env perl
use strict;
use warnings;
use Test::More tests => 10;

do {
    package Class;
    use Mouse;

    has 'x';

    has 'y' => (
        is => 'ro',
    );

    has 'z' => (
        is => 'rw',
    );
};

ok(!Class->can('x'), "No accessor is injected if 'is' has no value");
can_ok('Class', 'y', 'z');

my $object = Class->new;

ok(!$object->can('x'), "No accessor is injected if 'is' has no value");
can_ok($object, 'y', 'z');

is($object->y, undef);
is($object->y(10), undef);
is($object->y, undef);

is($object->z, undef);
is($object->z(10), 10);
is($object->z, 10);

