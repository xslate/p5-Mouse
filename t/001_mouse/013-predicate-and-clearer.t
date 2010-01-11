#!/usr/bin/env perl
use strict;
use warnings;
use Test::More;
use Test::Mouse;

my $lazy_run = 0;

do {
    package Class;
    use Mouse;

    has lazy => (
        is        => 'rw',
        lazy      => 1,
        default   => sub { ++$lazy_run },
        predicate => 'has_lazy',
        clearer   => 'clear_lazy',
    );
};

can_ok(Class => 'clear_lazy');

with_immutable(sub{

    $lazy_run = 0;
    my $object = Class->new;
    is($lazy_run, 0, "lazy attribute not yet initialized");

    ok(!$object->has_lazy, "no lazy value yet");
    is($lazy_run, 0, "lazy attribute not initialized by predicate");

    $object->clear_lazy;
    is($lazy_run, 0, "lazy attribute not initialized by clearer");

    ok(!$object->has_lazy, "no lazy value yet");
    is($lazy_run, 0, "lazy attribute not initialized by predicate");

    is($object->lazy, 1, "lazy value");
    is($lazy_run, 1, "lazy coderef invoked once");

    ok($object->has_lazy, "lazy value now");
    is($lazy_run, 1, "lazy coderef invoked once");

    is($object->lazy, 1, "lazy value is cached");
    is($lazy_run, 1, "lazy coderef invoked once");

    $object->clear_lazy;
    is($lazy_run, 1, "lazy coderef not invoked by clearer");

    ok(!$object->has_lazy, "no value now, clearer removed it");
    is($lazy_run, 1, "lazy attribute not initialized by predicate");

    is($object->lazy, 2, "new lazy value; previous was cleared");
    is($lazy_run, 2, "lazy coderef invoked twice");

    my $object2 = Class->new(lazy => 'very');
    is($lazy_run, 2, "lazy attribute not initialized when an argument is passed to the constructor");

    ok($object2->has_lazy, "lazy value now");
    is($lazy_run, 2, "lazy attribute not initialized when checked with predicate");

    is($object2->lazy, 'very', 'value from the constructor');
    is($lazy_run, 2, "lazy coderef not invoked, we already have a value");

    $object2->clear_lazy;
    is($lazy_run, 2, "lazy attribute not initialized by clearer");

    ok(!$object2->has_lazy, "no more lazy value");
    is($lazy_run, 2, "lazy attribute not initialized by predicate");

    is($object2->lazy, 3, 'new lazy value');
    is($lazy_run, 3, "lazy value re-created");

}, qw(Class));

done_testing;
