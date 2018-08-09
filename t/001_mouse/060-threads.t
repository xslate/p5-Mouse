#!perl

use strict;
use warnings;
use constant HAS_THREADS => eval{ require threads && require threads::shared };
use Test::More;

use if !HAS_THREADS, 'Test::More',
    (skip_all => "This is a test for threads ($@)");
use if $Test::More::VERSION >= 2.00, 'Test::More',
    (skip_all => "Test::Builder2 has bugs about threads");

{
    package MyTraits;
    use Mouse::Role;

    package MyClass;
    use Mouse;

    has foo => (
        is => 'rw',
        isa => 'Foo',
    );
    has bar => (
        is => 'rw',

        lazy    => 1,
        default => sub { 42 },
    );

    package Foo;
    use Mouse;

    has value => (
        is => 'rw',
        isa => 'Int',

        traits => [qw(MyTraits)],
    );
}
pass;

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

    is $x->bar, 42, 'callback for default';
})->join();

is $o->foo->value, 42;

$o = MyClass->new(foo => Foo->new(value => 43));
is $o->foo->value, 43;

ok !$o->meta->is_immutable;

pass "done";

done_testing;
