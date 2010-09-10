#!perl
use strict;
use warnings;
use lib 't/lib';

use Test::More;
use Test::Exception;

throws_ok {
    A->meta->add_around_method_modifier(bar => sub { "baz" });
} qr/The method 'bar' was not found in the inheritance hierarchy for A/;

{
    package A;
    use Mouse;

    sub foo { "foo" };
}

A->meta->add_around_method_modifier(foo => sub { "bar" });

is(A->foo(), 'bar', 'add_around_modifier');

done_testing;
