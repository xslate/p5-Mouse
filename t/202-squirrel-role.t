#!/usr/bin/perl

use strict;
use warnings;

use Test::More;
use Mouse::Util 'blessed';

do {
    package Foo::Role;
    use Squirrel::Role;

    has foo => (
        isa => "Int",
        is  => "rw",
    );

    no Squirrel::Role;
};

# note that 'Foo' is defined before this, to prevent Moose being loaded from
# affecting its definition

BEGIN {
    plan skip_all => "Moose required for this test" unless eval { require Moose::Role };
    plan tests => 6;
}

do {
    package Bar::Role;
    use Squirrel::Role;

    has foo => (
        isa => "Int",
        is  => "rw",
    );

    no Squirrel::Role;
};

ok(!Foo::Role->can('has'), "Mouse::Role::has was unimported");
SKIP: {
    skip "ancient moose", 1 if $Moose::VERSION <= 0.50;
    ok(!Bar::Role->can('has'), "Moose::Role::has was unimported");
}

eval "
    package Foo::Role;
    use Squirrel::Role;

    has bar => (is => 'rw');

    package Bar::Role;
    use Squirrel::Role;

    has bar => (is => 'rw');
";

isa_ok(Foo::Role->meta, 'Mouse::Meta::Role');
isa_ok(Foo::Role->meta, 'Mouse::Meta::Role');

isa_ok(Bar::Role->meta, 'Moose::Meta::Role');
isa_ok(Bar::Role->meta, 'Moose::Meta::Role');

