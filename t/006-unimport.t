#!/usr/bin/env perl
use strict;
use warnings;
use Test::More tests => 5;

do {
    package Class;
    use Mouse;

    no Mouse;

    package Child;
    use Mouse;
    extends 'Class';

    no Mouse;
};

ok(!Child->can('extends'), "extends keyword is unimported");
ok(!Class->can('extends'), "extends keyword is unimported");

do {
    package Foo;
    use Mouse 'has';

    sub extends { "good" }

    no Mouse;
};

ok(!Foo->can('has'), "has keyword is unimported");

ok(Foo->can('extends'), "extends method is NOT unimported");
is(eval { Foo->extends }, "good", "extends method is ours, not the extends keyword");

