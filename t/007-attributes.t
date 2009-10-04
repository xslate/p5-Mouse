#!/usr/bin/env perl
use strict;
use warnings;
use Test::More tests => 18;
use Test::Exception;

use lib 't/lib';
use Test::Mouse;

do {
    package Class;
    use Mouse;

    has 'x' => (
        is => 'bare',
    );

    has 'y' => (
        is => 'ro',
    );

    has 'z' => (
        is => 'rw',
    );

    has 'attr' => (
        accessor => 'rw_attr',
        reader   => 'read_attr',
        writer   => 'write_attr',
    );
};

ok(!Class->can('x'), "No accessor is injected if 'is' has no value");
can_ok('Class', 'y', 'z');

has_attribute_ok 'Class', 'x';
has_attribute_ok 'Class', 'y';
has_attribute_ok 'Class', 'z';

my $object = Class->new;

ok(!$object->can('x'), "No accessor is injected if 'is' has no value");
can_ok($object, 'y', 'z');

is($object->y, undef);

throws_ok {
    $object->y(10);
} qr/Cannot assign a value to a read-only accessor/;

is($object->y, undef);

is($object->z, undef);
is($object->z(10), 10);
is($object->z, 10);

can_ok($object, qw(rw_attr read_attr write_attr));
$object->write_attr(42);
is $object->rw_attr, 42;
is $object->read_attr, 42;
$object->rw_attr(100);
is $object->rw_attr, 100;
is $object->read_attr, 100;

