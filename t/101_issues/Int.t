#!/usr/bin/perl
use strict;
use warnings;
use Test::More;
use Mouse::Util::TypeConstraints;

my $Int    = find_type_constraint 'Int';

my $num = 3.14;

ok !$Int->check($num), "\$num (== 3.14) is not Int";

{ no warnings; int($num) };

ok !$Int->check($num), "\$num (== 3.14) is still not Int";

done_testing;
