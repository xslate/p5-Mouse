use strict;
use warnings;
use lib 't/lib';
use Test::More tests => 1;

{
    package Foo;
    use BaseClass;
}

is(Foo->new->foo(), 'bar');

