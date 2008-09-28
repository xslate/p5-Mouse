#!/usr/bin/env perl
use strict;
use warnings;
use Test::More tests => 2;

do {
    package Class;
    use Mouse;

    has attr => (
        is => 'rw',
    );

    package Class2;
    use Mouse::Tiny;

    has attr => (
        is => 'rw',
    );
};

is(Class->new(attr => 'a')->attr, 'a');
is(Class2->new(attr => 'b')->attr, 'b');

