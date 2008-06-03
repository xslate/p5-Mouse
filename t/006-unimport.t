#!/usr/bin/env perl
use strict;
use warnings;
use Test::More tests => 2;

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

