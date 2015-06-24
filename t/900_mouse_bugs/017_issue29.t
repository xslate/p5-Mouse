#!perl

package main;
use strict;
use warnings;
use constant HAS_THREADS => eval{ require threads && require threads::shared };
use Test::More;

use if !HAS_THREADS, 'Test::More',
    (skip_all => "This is a test for threads ($@)");
use if $Test::More::VERSION >= 2.00, 'Test::More',
    (skip_all => "Test::Builder2 has bugs about threads");

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
