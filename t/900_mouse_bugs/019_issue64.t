#!/usr/bin/perl
use strict;
use warnings;

use Test::More;
use File::Basename;
use File::Spec;

use lib File::Spec->catdir( dirname($0), basename($0, '.t') );

BEGIN {
    use_ok('Holder');
}

done_testing();

