#!/usr/bin/env perl
use strict;
use warnings;
use Test::More;

BEGIN {
    eval "use Test::Output;";
    plan skip_all => "Test::Output is required for this test" if $@;
    plan tests => 1;
}

do {
    package Parent;
    sub new { bless {}, shift }

    package Child;
    BEGIN { our @ISA = 'Parent' }
    use Mouse;
};

stderr_is(
    sub { package Child; __PACKAGE__->meta->make_immutable },
    "Not inlining a constructor for Child since it is not inheriting the default Mouse::Object constructor\n",
    'Mouse warns when it would have blown away the inherited constructor',
);

