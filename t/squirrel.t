#!/usr/bin/perl

use strict;
use warnings;

use Test::More;

{
    package Foo;
    use Squirrel;

    has foo => (
        isa => "Int",
        is  => "rw",
    );
}

# note that 'Foo' is defined before this, to prevent Moose being loaded from
# affecting its definition

BEGIN {
    plan skip_all => "Moose required for this test" unless eval { require Moose };
    plan 'no_plan';
}

{
    package Bar;
    use Squirrel;

    has foo => (
        isa => "Int",
        is  => "rw",
    );
}

my $foo = Foo->new( foo => 3 );

isa_ok( $foo, "Foo" );

isa_ok( $foo, "Mouse::Object" );

is( $foo->foo, 3, "accessor" );


my $bar = Bar->new( foo => 3 );

isa_ok( $bar, "Bar" );
isa_ok( $bar, "Moose::Object" );

is( $bar->foo, 3, "accessor" );
