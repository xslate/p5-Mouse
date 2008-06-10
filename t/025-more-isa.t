#!/usr/bin/env perl
use strict;
use warnings;
use Test::More tests => 7;
use Test::Exception;

do {
    package Class;
    use Mouse;

    has tb => (
        is  => 'rw',
        isa => 'Test::Builder',
    );
};

can_ok(Class => 'tb');

lives_ok {
    Class->new(tb => Test::Builder->new);
};

lives_ok {
    my $class = Class->new;
    $class->tb(Test::Builder->new);
    isa_ok($class->tb, 'Test::Builder');
};

throws_ok {
    Class->new(tb => 3);
} qr/Attribute \(tb\) does not pass the type constraint because: Validation failed for 'Test::Builder' failed with value 3/;

throws_ok {
    my $class = Class->new;
    $class->tb(3);
} qr/Attribute \(tb\) does not pass the type constraint because: Validation failed for 'Test::Builder' failed with value 3/;

throws_ok {
    Class->new(tb => Class->new);
} qr/Attribute \(tb\) does not pass the type constraint because: Validation failed for 'Test::Builder' failed with value Class=HASH\(\w+\)/;

