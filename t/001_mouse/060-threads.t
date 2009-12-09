#!perl
use strict;
use warnings;
use constant HAS_THREADS => eval{ require threads };

use Test::More HAS_THREADS ? (tests => 6) : (skip_all => "This is a test for threads ($@)");

{
    package MyClass;
    use Mouse;

    has foo => (
        is => 'rw',
        isa => 'Foo',
    );

    package Foo;
    use Mouse;

    has value => (
        is => 'rw',
    );
}

my $o = MyClass->new(foo => Foo->new(value => 42));
threads->create(sub{
    my $x = MyClass->new(foo => Foo->new(value => 1));
    is $x->foo->value, 1;

    $x->foo(Foo->new(value => 2));

    is $x->foo->value, 2;

    MyClass->meta->make_immutable();

    $x = MyClass->new(foo => Foo->new(value => 10));
    is $x->foo->value, 10;

    $x->foo(Foo->new(value => 20));

    is $x->foo->value, 20;
})->join();

is $o->foo->value, 42;
ok !$o->meta->is_immutable;

