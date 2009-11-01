#!perl
# This is based on Class-MOP/t/312_anon_class_leak.t
use strict;
use warnings;
use Test::More;

BEGIN {
    eval "use Test::LeakTrace 0.10;";
    plan skip_all => "Test::LeakTrace 0.10 is required for this test" if $@;
}

plan tests => 11;

{
    package MyClass;
    use Mouse;

    has simple => (is => 'rw');

    has w_int => (is => 'rw', isa => 'Int');
    has w_int_or_undef
              => (is => 'rw', isa => 'Int | Undef');
    has w_foo => (is => 'rw', isa => 'Foo');
    has w_aint=> (is => 'rw', isa => 'ArrayRef[Int]');
}

no_leaks_ok{
    MyClass->new();
};

my $o = MyClass->new;
no_leaks_ok {
    $o->simple(10);
};
no_leaks_ok {
    $o->simple();
};

no_leaks_ok {
    $o->w_int(10);
};
no_leaks_ok {
    $o->w_int();
};

no_leaks_ok {
    $o->w_int_or_undef(10);
};
no_leaks_ok {
    $o->w_int_or_undef();
};

my $foo = bless {}, 'Foo';
no_leaks_ok {
    $o->w_foo($foo);
};
no_leaks_ok {
    $o->w_int();
};

my $aref = [10];
no_leaks_ok {
    $o->w_aint($aref);
};
no_leaks_ok {
    $o->w_aint();
};



