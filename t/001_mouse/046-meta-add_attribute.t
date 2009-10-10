use strict;
use warnings;
use Test::More tests => 1;

{
    package Foo;
    use Mouse;
}
 
Foo->meta->add_attribute(
    'foo' => (
        is => 'ro',
        isa => 'Str',
        default => 'bar',
    )
);
is(Foo->new->foo, 'bar');
