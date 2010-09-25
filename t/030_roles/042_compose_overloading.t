use strict;
use warnings;
use Test::More tests => 1;

{
    package Foo;
    use Mouse::Role;

    use overload
        q{""}    => sub { 42 },
        fallback => 1;

    no Mouse::Role;
}

{
    package Bar;
    use Mouse;
    with 'Foo';
    no Mouse;
}

my $bar = Bar->new;

is("$bar", 42, 'overloading can be composed');
