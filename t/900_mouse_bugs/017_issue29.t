#!perl

package main;
use strict;
use warnings;
use Test::Requires qw(threads); # XXX: ithreads is discuraged!

use Test::More;

{
    package Foo;
    use Mouse;

    has syntax => (
        is      => 'rw',
        isa     => 'Str',
        default => 'Kolon',
    );

}

my $foo = Foo->new;
is $foo->syntax, "Kolon";

threads->create(sub{
    is $foo->syntax, "Kolon";
})->join();

done_testing;
