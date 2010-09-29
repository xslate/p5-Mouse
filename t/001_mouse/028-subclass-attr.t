#!/usr/bin/env perl
use strict;
use warnings;
use Test::More;
use Test::Mouse;
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

    package CA;
    use Mouse;
    extends qw(Class);
    has ca => (is => 'rw');
    package CB;
    use Mouse;
    extends qw(Class);
    has cb => (is => 'rw');
    package CC;
    use Mouse;
    extends qw(CB CA);
    has cc => (is => 'rw');
};
with_immutable {
    my $obj = Child->new(class => 1, child => 1);
    ok($obj->child, "local attribute set in constructor");
    ok($obj->class, "inherited attribute set in constructor");

    is_deeply([sort(Child->meta->get_all_attributes)], [sort(
        Child->meta->get_attribute('child'),
        Class->meta->get_attribute('class'),
    )], "correct get_all_attributes");

    is_deeply([sort(CC->meta->get_all_attributes)], [sort(
        CC->meta->get_attribute('cc'),
        CB->meta->get_attribute('cb'),
        CA->meta->get_attribute('ca'),
        Class->meta->get_attribute('class'),
    )], "correct get_all_attributes");
} 'Class', 'CA', 'CB', 'CC';

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

with_immutable {
    my $foo = Foo->new;
    is($foo->attr, 'Foo', 'subclass does not affect parent attr');

    my $bar = Bar->new;
    is($bar->attr, undef, 'new attribute does not have the new default');

    is(Foo->meta->get_attribute('attr')->default, 'Foo');
    is(Foo->meta->get_attribute('attr')->_is_metadata, 'ro');

    is(Bar->meta->get_attribute('attr')->default, undef);
    is(Bar->meta->get_attribute('attr')->_is_metadata, 'rw');

    is_deeply([Foo->meta->get_all_attributes], [
        Foo->meta->get_attribute('attr'),
    ], "correct get_all_attributes");

    is_deeply([Bar->meta->get_all_attributes], [
        Bar->meta->get_attribute('attr'),
    ], "correct get_all_attributes");
} 'Foo', 'Bar';

done_testing;

