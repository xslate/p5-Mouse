#!perl
use strict;
use warnings;
use Test::More tests => 3;

use Tie::Scalar;

{
    package MyClass;
    use Mouse;

    has foo => (
        is  => 'rw',
        isa => 'Int',
    );
    has bar => (
        is  => 'rw',
        isa => 'Maybe[Int]',
    );
}

sub ts_init {
    tie $_[0], 'Tie::StdScalar', $_[1];
}

ts_init(my $x, 10);

my $o = MyClass->new();
is(eval{ $o->foo($x) }, 10)
    or diag("Error: $@");

ts_init($x, 'foo');

eval{
    $o->bar($x);
};
isnt $@, '';

ts_init $x, 42;
is(eval{ $o->bar($x) }, 42)
    or diag("Error: $@");

