#!/usr/bin/env perl
package Mouse::TypeRegistry;
use strict;
use warnings;

sub optimized_constraints {
    return {
        Any        => sub { 1 },
        Item       => sub { 1 },
        Bool       => sub {
            !defined($_) || $_ eq "" || "$_" eq '1' || "$_" eq '0'
        },
        Undef      => sub { !defined($_) },
        Defined    => sub { defined($_) },
        Value      => sub { 1 },
        Num        => sub { 1 },
        Int        => sub { 1 },
        Str        => sub { 1 },
        ClassName  => sub { 1 },
        Ref        => sub { 1 },
        ScalarRef  => sub { 1 },
        ArrayRef   => sub { 1 },
        HashRef    => sub { 1 },
        CodeRef    => sub { 1 },
        RegexpRef  => sub { 1 },
        GlobRef    => sub { 1 },
        FileHandle => sub { 1 },
        Object     => sub { 1 },
    };
}

1;

