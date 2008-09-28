#!perl -T
use strict;
use warnings;
use Test::More tests => 1;

use_ok 'Mouse';

diag "Soft dependency versions:";
for my $module_name (keys %Mouse::Util::loaded) {
    my $version;
    if ($Mouse::Util::loaded{$module_name}) {
        no strict 'refs';
        $version = ${$module_name . '::VERSION'};
    }
    else {
        $version = "(provided by Mouse::Util)";
    }

    diag "    $module_name: $version";
}

