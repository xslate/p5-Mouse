#!/usr/bin/perl

use strict;
use warnings;

use Test::More tests => 4;
use Test::Exception;

{
    package Foo;

    use Mouse::Util::TypeConstraints;

    eval {
        type MyRef => where { ref($_) };
    };
    ::ok( !$@, '... successfully exported &type to Foo package' );

    eval {
        subtype MyArrayRef => as MyRef => where { ref($_) eq 'ARRAY' };
    };
    ::ok( !$@, '... successfully exported &subtype to Foo package' );

    Mouse::Util::TypeConstraints->export_type_constraints_as_functions();

    ::ok( MyRef( {} ), '... Ref worked correctly' );
    ::ok( MyArrayRef( [] ), '... ArrayRef worked correctly' );
}
