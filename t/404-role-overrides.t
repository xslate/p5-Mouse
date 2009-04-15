#!/usr/bin/env perl
use strict;
use warnings;
use Test::More tests => 2;

do {
    package My::Role;
    use Mouse::Role;

    sub foo { 'role' }

    package Parent;
    use Mouse;

    sub foo { 'parent' }

    package Child;
    use Mouse;
    extends 'Parent';
    with 'My::Role';
};

is(Child->foo, 'role');

do {
    package ChildOverride;
    use Mouse;
    extends 'Parent';
    with 'My::Role';

    sub foo { 'child' }
};

is(ChildOverride->foo, 'child');

