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
        isa => 'Int',
    );
}

my $o = MyClass->new(foo => 42);
threads->create(sub{
    my $x = MyClass->new(foo => 1);
    is $x->foo, 1;

    $x->foo(2);

    is $x->foo, 2;

    MyClass->meta->make_immutable();

    $x = MyClass->new(foo => 10);
    is $x->foo, 10;

    $x->foo(20);

    is $x->foo, 20;
})->join();

is $o->foo, 42;
ok !$o->meta->is_immutable;

