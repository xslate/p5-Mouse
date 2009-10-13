#!/usr/bin/perl -w
use Test;

plan tests => 3;

{
    package Class;
    sub new {}
}

{
    package MouseClass;
    use Mouse;
}


{
    package Foo;

    use Mouse;

    has unknown => (
        is  => 'rw',
        isa => 'HashRef[Unknown]'
    );

    has class   => (
        is      => 'rw',
        isa     => 'HashRef[Class]',
    );

    has mouse   => (
        is      => 'rw',
        isa     => 'HashRef[MouseClass]',
    );
}


my $obj = Foo->new;
ok eval { $obj->unknown({}); };
ok eval { $obj->class({}); };
ok eval { $obj->mouse({}); };
