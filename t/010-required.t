#!/usr/bin/env perl
use strict;
use warnings;
use Test::More tests => 3;
use Test::Exception;

do {
    package Class;
    use Mouse;

    has foo => (
        is => 'bare',
        required => 1,
    );

    has bar => (
        is => 'bare',
        required => 1,
        default => 50,
    );

    has baz => (
        is => 'bare',
        required => 1,
        default => sub { 10 },
    );

    has quux => (
        is       => "rw",
        required => 1,
        lazy     => 1,
        default  => sub { "yay" },
    );
};

throws_ok { Class->new } qr/Attribute \(foo\) is required/, "required attribute is required";
lives_ok { Class->new(foo => 5) } "foo is the only required but unfulfilled attribute";
lives_ok { Class->new(foo => 1, bar => 1, baz => 1, quux => 1) } "all attributes specified";

