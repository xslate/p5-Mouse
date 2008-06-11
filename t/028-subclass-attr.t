#!/usr/bin/env perl
use strict;
use warnings;
use Test::More tests => 2;

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
