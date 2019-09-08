#!/usr/bin/perl
use strict;
use warnings;
use Test::More;
use Mouse::Util::TypeConstraints;

my $Int = find_type_constraint 'Int';

subtest "Non-Int from numerical literal: my \$num = 3.14", sub {
    my $num = 3.14;
    ok !$Int->check($num), "\$num is not Int";
    { no warnings; int($num) };
    ok !$Int->check($num), "\$num is still not Int";
};

subtest "Non-Int from string literal: my \$num = \"3.14\"", sub {
    my $num = "3.14";
    ok !$Int->check($num), "\$num is not Int";
    { no warnings; int($num) };
    ok !$Int->check($num), "\$num is still not Int";
};

subtest "Int from string literal: my \$num = \"3\"", sub {
    my $num = "3";
    ok $Int->check($num), "\$num is Int";
    { no warnings; int($num) };
    ok $Int->check($num), "\$num is still Int";
};

subtest "Int from integer literal: my \$num = 3", sub {
    my $num = 3;
    ok $Int->check($num), "\$num is Int";
    { no warnings; int($num) };
    ok $Int->check($num), "\$num is still Int";
};

subtest "MAXUINT", sub {
    my $maxuint = ~0;
    ok $Int->check( $maxuint ), 'yes MAXUINT';
    my $as_string = sprintf '%f', $maxuint;
    ok $Int->check( $maxuint ), 'yes MAXUINT after use as float';
};

done_testing;
