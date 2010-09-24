#!/usr/bin/perl

use strict;
use warnings;

use Test::More tests => 40;


my @moose_exports = qw(
    extends with
    has
    before after around
    override
    augment
    super inner
);

{
    package Foo;

    eval 'use Mouse';
    die $@ if $@;
}

can_ok('Foo', $_) for @moose_exports;

{
    package Foo;

    eval 'no Mouse';
    die $@ if $@;
}

ok(!Foo->can($_), '... Foo can no longer do ' . $_) for @moose_exports;

# and check the type constraints as well

my @moose_type_constraint_exports = qw(
    type subtype as where message
    coerce from via
    enum
    find_type_constraint
);

{
    package Bar;

    eval 'use Mouse::Util::TypeConstraints';
    die $@ if $@;
}

can_ok('Bar', $_) for @moose_type_constraint_exports;

{
    package Bar;

    eval 'no Mouse::Util::TypeConstraints';
    die $@ if $@;
}


ok(!Bar->can($_), '... Bar can no longer do ' . $_) for @moose_type_constraint_exports;


