#!/usr/bin/env perl
use strict;
use warnings;
use Test::More tests => 16;
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

    package Shirt::Anon;
    use Mouse;
    use Mouse::Util::TypeConstraints 'enum';

    has size => (
        is  => 'rw',
        isa => enum ['small', 'medium', 'large'],
    );
};

for my $class ('Shirt', 'Shirt::Anon') {
    ok($class->new(size => 'small'));
    ok($class->new(size => 'medium'));
    ok($class->new(size => 'large'));

    throws_ok { $class->new(size => 'extra small') } qr/^Attribute \(size\) does not pass the type constraint because: Validation failed for '\S+' failed with value extra small/;
    throws_ok { $class->new(size => 'Small') } qr/^Attribute \(size\) does not pass the type constraint because: Validation failed for '\S+' failed with value Small/;
    throws_ok { $class->new(size => '') } qr/^Attribute \(size\) does not pass the type constraint because: Validation failed for '\S+' failed with value /;
    throws_ok { $class->new(size => 'small ') } qr/^Attribute \(size\) does not pass the type constraint because: Validation failed for '\S+' failed with value small /;
    throws_ok { $class->new(size => ' small') } qr/^Attribute \(size\) does not pass the type constraint because: Validation failed for '\S+' failed with value  small/;
}

