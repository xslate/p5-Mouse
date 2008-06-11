#!/usr/bin/env perl
use strict;
use warnings;
use Test::More tests => 3;

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

