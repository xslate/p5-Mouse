#!/usr/bin/env perl
use Test::More tests => 1;

# we used to use Test::Warn here but there's no point in adding three deps total
# for this one easy test

my @warnings;
local $SIG{__WARN__} = sub {
    push @warnings, "@_";
};

do {
    package Class;
    use Mouse;

    my $one = 1 + undef;
};

like("@warnings", qr/^Use of uninitialized value/, 'using Mouse turns on warnings');

