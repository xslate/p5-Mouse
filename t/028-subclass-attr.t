#!/usr/bin/env perl
use strict;
use warnings;
use Test::More tests => 11;

do {
    package Class;
    use Mouse;

    has class => (
        is  => 'rw',
        isa => 'Bool',
    );

    package Child;
    use Mouse;
    extends 'Class';

    has child => (
        is  => 'rw',
        isa => 'Bool',
    );
};

my $obj = Child->new(class => 1, child => 1);
ok($obj->child, "local attribute set in constructor");
ok($obj->class, "inherited attribute set in constructor");

is_deeply([Child->meta->compute_all_applicable_attributes], [
    Child->meta->get_attribute('child'),
    Class->meta->get_attribute('class'),
], "correct compute_all_applicable_attributes");

do {
    package Foo;
    use Mouse;

    has attr => (
        is      => 'ro',
        default => 'Foo',
    );

    package Bar;
    use Mouse;
    extends 'Foo';

    has attr => (
        is => 'rw',
    );
};

my $foo = Foo->new;
is($foo->attr, 'Foo', 'subclass does not affect parent attr');

my $bar = Bar->new;
is($bar->attr, undef, 'new attribute does not have the new default');

is(Foo->meta->get_attribute('attr')->default, 'Foo');
is(Foo->meta->get_attribute('attr')->_is_metadata, 'ro');

is(Bar->meta->get_attribute('attr')->default, undef);
is(Bar->meta->get_attribute('attr')->_is_metadata, 'rw');

is_deeply([Foo->meta->compute_all_applicable_attributes], [
    Foo->meta->get_attribute('attr'),
], "correct compute_all_applicable_attributes");

is_deeply([Bar->meta->compute_all_applicable_attributes], [
    Bar->meta->get_attribute('attr'),
], "correct compute_all_applicable_attributes");

