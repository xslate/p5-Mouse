#!perl

package main;
use strict;
use warnings;
use Test::More skip_all => 'See https://github.com/gfx/p5-Mouse/issues/29';

use Test::Requires qw(threads); # XXX: ithreads is discuraged!


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
