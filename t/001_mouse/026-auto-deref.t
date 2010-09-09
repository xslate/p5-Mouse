#!/usr/bin/env perl
use strict;
use warnings;
use Test::More tests => 15;
use Test::Exception;

do {
    package Class;
    use Mouse;

    has array => (
        is         => 'rw',
        isa        => 'ArrayRef',
        auto_deref => 1,
    );

    has hash => (
        is         => 'rw',
        isa        => 'HashRef',
        auto_deref => 1,
    );

    ::throws_ok {
        has any => (
            is         => 'rw',
            auto_deref => 1,
        );
    } qr/You cannot auto-dereference without specifying a type constraint on attribute \(any\)/;

    ::throws_ok {
        has scalar => (
            is         => 'rw',
            isa        => 'Value',
            auto_deref => 1,
        );
    } qr/You cannot auto-dereference anything other than a ArrayRef or HashRef on attribute \(scalar\)/;
};

my $obj;
lives_ok {
    $obj = Class->new;
} "auto_deref without defaults don't explode on new";

my ($array, @array, $hash, %hash);
lives_ok {
    @array = $obj->array;
    %hash  = $obj->hash;
    $array = $obj->array;
    $hash  = $obj->hash;

    $obj->array;
    $obj->hash;
} "auto_deref without default doesn't explode on get";

is($obj->array, undef, "array without value is undef in scalar context");
is($obj->hash, undef, "hash without value is undef in scalar context");

is(@array, 0, "array without value is empty in list context");
is(keys %hash, 0, "hash without value is empty in list context");

@array = $obj->array([1, 2, 3]);
%hash  = $obj->hash({foo => 1, bar => 2});

is_deeply(\@array, [1, 2, 3], "setter returns the dereferenced list");
is_deeply(\%hash, {foo => 1, bar => 2}, "setter returns the dereferenced hash");

lives_ok {
    @array = $obj->array;
    %hash  = $obj->hash;
    $array = $obj->array;
    $hash  = $obj->hash;

    $obj->array;
    $obj->hash;
} "auto_deref without default doesn't explode on get";

is_deeply($array, [1, 2, 3], "auto_deref in scalar context gives the reference");
is_deeply($hash, {foo => 1, bar => 2}, "auto_deref in scalar context gives the reference");

is_deeply(\@array, [1, 2, 3], "auto_deref in list context gives the list");
is_deeply(\%hash, {foo => 1, bar => 2}, "auto_deref in list context gives the hash");

