#!perl
use strict;
use warnings;
use Test::More;

BEGIN{
    if($] < 5.008){
        plan skip_all => "segv happens on 5.6.2";
    }
}
use Test::More tests => 4;

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
}

ok does_role(BaseClass->meta, 'FooTrait'), ' BaseClass->meta->does("FooTrait")';
ok!does_role(BaseClass->meta, 'BarTrait'), '!BaseClass->meta->does("BarTrait")';

ok does_role(SubClass->meta,  'FooTrait'), 'SubClass->meta->does("FooTrait")';
ok does_role(SubClass->meta,  'BarTrait'), 'SubClass->meta->does("BarTrait")';

