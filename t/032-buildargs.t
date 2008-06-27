#!/usr/bin/env perl
use strict;
use warnings;
use Test::More tests => 3;

do {
    package Foo;
    use Mouse;

    has foo => ( is => "rw" );

    sub BUILDARGS {
        my ( $self, @args ) = @_;
        return { @args % 2 ? ( foo => @args ) : @args };
    }
};

is(Foo->new->foo, undef, "no value");
is(Foo->new("bar")->foo, "bar", "single arg");
is(Foo->new(foo => "bar")->foo, "bar", "twoargs");

