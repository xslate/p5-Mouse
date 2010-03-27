#!perl -w

package Foo;
use Mouse;

has bar => (
    is => 'rw',

    trigger => sub {
        eval 'BEGIN{ die }';
    },
    default => sub {
        eval 'BEGIN{ die }';
        return 42;
    },
);

sub BUILDARGS {
    eval 'BEGIN{ die }';
    return {};
}

sub BUILD {
    eval 'BEGIN{ die }';
}

package main;

use Test::More tests => 3;

$@ = '(ERRSV)';

my $foo = Foo->new;
isa_ok $foo, 'Foo';
is $foo->bar, 42;
$foo->bar(100);
is $foo->bar, 100;
note("\$@=$@");
