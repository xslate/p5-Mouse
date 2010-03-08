#!perl
use strict;
use warnings;

use Test::More;

use Mouse::Util qw(does_role);

{
    package FooTrait;
    use Mouse::Role;

    package BarTrait;
    use Mouse::Role;

    package BaseClass;
    use Mouse -traits => qw(FooTrait);

    package SubClass;
    use Mouse -traits => qw(BarTrait);

    extends qw(BaseClass);

    package SubSubClass;
    use Mouse;

    extends qw(SubClass);
}

ok does_role(BaseClass->meta, 'FooTrait'), ' BaseClass->meta->does("FooTrait")';
ok!does_role(BaseClass->meta, 'BarTrait'), '!BaseClass->meta->does("BarTrait")';

ok does_role(SubClass->meta,  'FooTrait'), 'SubClass->meta->does("FooTrait")';
ok does_role(SubClass->meta,  'BarTrait'), 'SubClass->meta->does("BarTrait")';

ok does_role(SubSubClass->meta,  'FooTrait'), 'SubSubClass->meta->does("FooTrait")';
ok does_role(SubSubClass->meta,  'BarTrait'), 'SubSubClass->meta->does("BarTrait")';

done_testing;
