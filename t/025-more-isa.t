#!/usr/bin/env perl
use strict;
use warnings;
use Test::More tests => 23;
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

do {
    package Other;
    use Mouse;

    has oops => (
        isa     => 'Int',
        default => "yikes",
    );
};

throws_ok {
    Other->new;
} qr/Attribute \(oops\) does not pass the type constraint because: Validation failed for 'Int' failed with value yikes/;

lives_ok {
    Other->new(oops => 10);
};

# ClassName coverage tests

do {
    package A;
    our $VERSION = 1;

    package B;
    our @ISA = 'Mouse::Object';

    package C;
    sub foo {}

    package D::Child;
    sub bar {}

    package E;

    package F;
    our $NOT_CODE = 1;
};

do {
    package ClassNameTests;
    use Mouse;

    has class => (
        is => 'rw',
        isa => 'ClassName',
    );
};

for ('A'..'C', 'D::Child') {
    lives_ok {
        ClassNameTests->new(class => $_);
    };

    lives_ok {
        my $obj = ClassNameTests->new;
        $obj->class($_);
    };
}

for ('E'..'F', 'NonExistentClass') {
    throws_ok {
        ClassNameTests->new(class => $_);
    } qr/Attribute \(class\) does not pass the type constraint because: Validation failed for 'ClassName' failed with value $_/;

    throws_ok {
            my $obj = ClassNameTests->new;
            $obj->class($_);
    } qr/Attribute \(class\) does not pass the type constraint because: Validation failed for 'ClassName' failed with value $_/;
};

