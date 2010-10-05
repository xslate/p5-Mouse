#!/usr/bin/env perl
use strict;
use warnings;
use Test::More;
use Test::Exception;
use Test::Mouse;

use lib 't/lib';
use MooseCompat;

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
    has 'attr2' => (
        is       => 'rw',
        accessor => 'rw_attr2',
    );
};
with_immutable {
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

    is $object->write_attr("piyo"), "piyo";
    is $object->rw_attr("yopi"),    "yopi";

    can_ok $object, qw(rw_attr2);
    ok !$object->can('attr2'), "doesn't have attr2";

    dies_ok {
        Class->rw_attr();
    };
    dies_ok {
        Class->read_attr();
    };
    dies_ok {
        Class->write_attr(42);
    };

    my @attrs = map { $_->name }
        sort { $a->insertion_order <=> $b->insertion_order } $object->meta->get_all_attributes;
    is join(' ', @attrs), 'x y z attr attr2', 'insertion_order';
} qw(Class);
done_testing;
