#!/usr/bin/env perl
use strict;
use warnings;
use Test::More;

my $lazy_run = 0;

do {
    package Class;
    use Mouse;

    has lazy => (
        is      => 'rw',
        lazy    => 1,
        default => sub { ++$lazy_run },
    );

    has lazy_value => (
        is      => 'rw',
        lazy    => 1,
        default => "welp",
    );

    eval {
        has lazy_no_default => (
            is   => 'rw',
            lazy => 1,
        );
    };
    ::like $@, qr/You cannot have a lazy attribute \(lazy_no_default\) without specifying a default value for it/;
};

my $object = Class->new;
is($lazy_run, 0, "lazy attribute not yet initialized");

is($object->lazy, 1, "lazy coderef");
is($lazy_run, 1, "lazy coderef invoked once");

is($object->lazy, 1, "lazy coderef is cached");
is($lazy_run, 1, "lazy coderef invoked once");

is($object->lazy_value, 'welp', "lazy value");
is($lazy_run, 1, "lazy coderef invoked once");

is($object->lazy_value("newp"), "newp", "set new value");
is($lazy_run, 1, "lazy coderef invoked once");

is($object->lazy_value, "newp", "got new value");
is($lazy_run, 1, "lazy coderef invoked once");

is($object->lazy(42), 42);
is($object->lazy_value(3.14), 3.14);

my $object2 = Class->new(lazy => 'very', lazy_value => "heh");
is($lazy_run, 1, "lazy attribute not initialized when an argument is passed to the constructor");

is($object2->lazy, 'very', 'value from the constructor');
is($object2->lazy_value, 'heh', 'value from the constructor');
is($lazy_run, 1, "lazy coderef not invoked, we already have a value");

done_testing;
