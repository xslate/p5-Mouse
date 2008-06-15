#!/usr/bin/env perl
use strict;
use warnings;
use Test::More tests => 2;

do {
    package Class;
    use Mouse;

    has attr => (
        is  => 'rw',
        isa => 'Bool',
    );

    package Child;
    use Mouse;
    extends 'Class';

    has '+attr' => (
        default => 1,
    );
};

my $obj = Class->new;
ok(!$obj->attr, 'has + does not affect the superclass');

my $obj2 = Child->new;
ok($obj2->attr, 'has + combines child attribute with parent');

