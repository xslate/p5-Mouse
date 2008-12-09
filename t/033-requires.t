#!perl
use strict;
use warnings;
use Test::More tests => 1;
use Test::Exception;

{
    package Foo;
    use Mouse::Role;
    requires 'foo';
}

throws_ok {
    package Bar;
    use Mouse;
    with 'Foo';
} qr/'Foo' requires the method 'foo' to be implemented by 'Bar'/;

{
    package Baz;
    use Mouse;
    with 'Foo';
    sub foo { }
}

