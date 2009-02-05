#!/usr/bin/env perl
use strict;
use warnings;
use Test::More;

BEGIN {
    eval "use Test::Output;";
    plan skip_all => "Test::Output is required for this test" if $@;
    plan tests => 3;
}

do {
    package Parent;
    sub new { bless {}, shift }

    package Child;
    BEGIN { our @ISA = 'Parent' }
    use Mouse;
};

TODO: {
    local $TODO = "Mouse doesn't track enough context";
    stderr_is(
        sub { Child->meta->make_immutable },
        "Not inlining a constructor for Child since it is not inheriting the default Mouse::Object constructor\n",
        'Mouse warns when it would have blown away the inherited constructor',
    );
}

do {
    package Foo;
    use Mouse;

    __PACKAGE__->meta->make_immutable;

    package Bar;
    use Mouse;
    extends 'Foo';

};

stderr_is(
    sub { Bar->meta->make_immutable },
    "",
    'Mouse does not warn about inlining a constructor when the superclass inlined a constructor',
);

do {
    package Baz;

    package Quux;
    BEGIN { our @ISA = 'Baz' }
    use Mouse;

    __PACKAGE__->meta->make_immutable;
};

ok(Quux->new);

