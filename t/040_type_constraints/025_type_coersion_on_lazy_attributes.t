#!/usr/bin/perl

use strict;
use warnings;

use Test::More tests => 1;

{
    package SomeClass;
    use Mouse;
    use Mouse::Util::TypeConstraints;

    subtype 'DigitSix' => as 'Num'
        => where { /^6$/ };
    subtype 'TextSix' => as 'Str'
        => where { /Six/i };

    coerce 'TextSix'
        => from 'DigitSix'
        => via { confess("Cannot live without 6 ($_)") unless /^6$/; 'Six' };

    has foo => (
        is      => 'ro',
        isa     => 'TextSix',
        coerce  => 1,
        default => 6,
        lazy    => 1
    );
}

is(SomeClass->new()->foo, 'Six');


