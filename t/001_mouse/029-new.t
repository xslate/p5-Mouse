#!/usr/bin/env perl
use strict;
use warnings;
use Test::More tests => 7;
use Test::Exception;

do {
    package Class;
    use Mouse;

    has x => (
        is => 'bare',
    );

    has y => (
        is => 'ro',
    );

    has z => (
        is => 'rw',
    );
};

my $object = Class->new({x => 1, y => 2, z => 3});
is($object->{x}, 1);
is($object->y, 2);
is($object->z, 3);

throws_ok {
    Class->new('non-hashref scalar');
} qr/Single parameters to new\(\) must be a HASH ref/;

throws_ok {
    Class->new(undef);
} qr/Single parameters to new\(\) must be a HASH ref/;

Class->meta->make_immutable;

throws_ok {
    Class->new([]);
} qr/Single parameters to new\(\) must be a HASH ref/;

throws_ok {
    Class->new(Class->new);
} qr/Single parameters to new\(\) must be a HASH ref/;
