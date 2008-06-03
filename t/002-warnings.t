#!/usr/bin/env perl
use Test::More tests => 1;
use Test::Warn;

warning_like {
    package Class;
    use Mouse;

    my $one = 1 + undef;
} qr/uninitialized value/, 'using Mouse turns on warnings';

