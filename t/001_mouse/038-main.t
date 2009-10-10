#!/usr/bin/env perl
use strict;
use warnings;
use Test::More;

BEGIN {
    eval "use Test::Output;";
    plan skip_all => "Test::Output is required for this test" if $@;
    plan tests => 2;
}

stderr_is(
    sub { package main; eval 'use Mouse' },
    "Mouse does not export its sugar to the 'main' package.\n",
    'Mouse warns when loaded from the main package',
);

stderr_is(
    sub { package main; eval 'use Mouse::Role' },
    "Mouse::Role does not export its sugar to the 'main' package.\n",
    'Mouse::Role warns when loaded from the main package',
);

