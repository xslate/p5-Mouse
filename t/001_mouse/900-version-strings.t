#!perl -T
use strict;
use warnings;
use Test::More tests => 10;

require_ok 'Mouse';
require_ok 'Mouse::Util';
require_ok 'Mouse::Tiny';
require_ok 'Mouse::Spec';
require_ok 'Mouse::Role';


for my $module ( qw( Mouse Mouse::Util Mouse::Tiny Mouse::Spec Mouse::Role ) ){
    ok( $module->VERSION =~ /^v/, "Version number should start with 'v' in $module!" );
}


