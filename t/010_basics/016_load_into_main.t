#!/usr/bin/perl

use strict;
use warnings;

use Test::More;
BEGIN {
    eval "use Test::Output;";
    plan skip_all => "Test::Output is required for this test" if $@;
    plan tests => 2;
}

stderr_like( sub { package main; eval 'use Mouse' },
             qr/\QMouse does not export its sugar to the 'main' package/,
             'Mouse warns when loaded from the main package' );

stderr_like( sub { package main; eval 'use Mouse::Role' },
             qr/\QMouse::Role does not export its sugar to the 'main' package/,
             'Mouse::Role warns when loaded from the main package' );
