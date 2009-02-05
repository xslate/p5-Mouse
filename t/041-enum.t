#!/usr/bin/env perl
use strict;
use warnings;
use Test::More tests => 8;
use Test::Exception;

do {
    package Shirt;
    use Mouse;
    use Mouse::Util::TypeConstraints 'enum';

    enum 'Size' => qw(small medium large);

    has size => (
        is  => 'rw',
        isa => 'Size',
    );
};

ok(Shirt->new(size => 'small'));
ok(Shirt->new(size => 'medium'));
ok(Shirt->new(size => 'large'));

throws_ok { Shirt->new(size => 'extra small') } qr/^Attribute \(size\) does not pass the type constraint because: Validation failed for 'Size' failed with value extra small/;
throws_ok { Shirt->new(size => 'Small') } qr/^Attribute \(size\) does not pass the type constraint because: Validation failed for 'Size' failed with value Small/;
throws_ok { Shirt->new(size => '') } qr/^Attribute \(size\) does not pass the type constraint because: Validation failed for 'Size' failed with value /;
throws_ok { Shirt->new(size => 'small ') } qr/^Attribute \(size\) does not pass the type constraint because: Validation failed for 'Size' failed with value small /;
throws_ok { Shirt->new(size => ' small') } qr/^Attribute \(size\) does not pass the type constraint because: Validation failed for 'Size' failed with value  small/;

