#!/usr/bin/perl

use strict;
use warnings;

use Test::More 'no_plan';

{
    package Foo;
    use Mouse;

    has foo => (
        isa => "Str",
        is  => "rw",
        default => "foo",
    );

    has bar => (
        isa => "ArrayRef",
        is  => "rw",
    );

    sub clone {
        my ( $self, @args ) = @_;
        $self->meta->clone_object( $self, @args );
    }
}

my $foo = Foo->new( bar => [ 1, 2, 3 ] );

is( $foo->foo, "foo", "attr 1", );
is_deeply( $foo->bar, [ 1 .. 3 ], "attr 2" );

my $clone = $foo->clone( foo => "dancing" );

is( $clone->foo, "dancing", "overridden attr" );
is_deeply( $clone->bar, [ 1 .. 3 ], "clone attr" );

