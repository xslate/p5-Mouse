#!/usr/bin/env perl
use strict;
use warnings;
use Test::More tests => 3;

do {
    package Class;
    use Mouse;
};

can_ok(Class => 'new');

my $object = Class->new;

isa_ok($object => 'Class');
isa_ok($object => 'Mouse::Object');

