#!/usr/bin/env perl
use strict;
use warnings;
use Test::More tests => 30;
use Mouse::Util ':test';

do {
    package Class;
    use Mouse;

    has tb => (
        is  => 'rw',
        isa => 'Test::Builder',
    );

    package Test::Builder::Subclass;
    our @ISA = qw(Test::Builder);
};

can_ok(Class => 'tb');

lives_ok {
    Class->new(tb => Test::Builder->new);
};

lives_ok {
    # Test::Builder was a bizarre choice, because it's a singleton.  Because of
    # that calling new on T:B:S won't work.  Blessing directly -- rjbs,
    # 2008-12-04
    Class->new(tb => (bless {} => 'Test::Builder::Subclass'));
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
    our @VERSION;

    package B;
    our $VERSION = 1;

    package C;
    our %ISA;

    package D;
    our @ISA = 'Mouse::Object';

    package E;
    sub foo {}

    package F;

    package G::H;
    sub bar {}

    package I;
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

for ('A'..'E', 'G::H') {
    lives_ok {
        ClassNameTests->new(class => $_);
    };

    lives_ok {
        my $obj = ClassNameTests->new;
        $obj->class($_);
    };
}

for ('F', 'G', 'I', 'Z') {
    throws_ok {
        ClassNameTests->new(class => $_);
    } qr/Attribute \(class\) does not pass the type constraint because: Validation failed for 'ClassName' failed with value $_/;

    throws_ok {
            my $obj = ClassNameTests->new;
            $obj->class($_);
    } qr/Attribute \(class\) does not pass the type constraint because: Validation failed for 'ClassName' failed with value $_/;
};

