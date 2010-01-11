#!/usr/bin/env perl
use strict;
use warnings;
use Test::More;
use lib 't/lib';

# auto-subclass
do {
    package Class;
    use Mouse;
};

can_ok(Class => 'new');

my $object = Class->new;

isa_ok($object => 'Class');
isa_ok($object => 'Mouse::Object');

# extends()
do {
    package ParentClass;
    use Mouse;

    package Child;
    use Mouse;
    extends 'ParentClass';

    package Mouse::TestClass;
    use Mouse;
    extends 'Unsweetened'; # in t/lib

    sub mouse { 1 }
};

can_ok(Child => 'new');

my $child = Child->new;

isa_ok($child => 'Child');
isa_ok($child => 'ParentClass');
isa_ok($child => 'Mouse::Object');

can_ok('Mouse::TestClass' => qw(mouse unsweetened));

eval q{
    package Child;
    use Mouse;
};

isa_ok($child => 'ParentClass');
isa_ok($child => 'Mouse::Object');

done_testing;
