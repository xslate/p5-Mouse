#!/usr/bin/perl

use strict;
use warnings;

use Test::More 'no_plan';
use Test::Exception;

{
    package Foo;
    use Mouse;

    has foo => ( is => "rw" );

    package Bar;
    sub oink { "oink" }

    package Gorch;
    use Mouse;

    extends qw(Bar Foo);

    ::lives_ok{
        has '+foo' => ( default => "the default" );
    } 'inherit attr when @ISA contains a non Mouse class before a Mouse class with the base attr';
}

{
    my $g = Gorch->new;

    is( $g->foo, "the default", "inherited attribute" );
}


