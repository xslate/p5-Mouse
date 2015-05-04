#!perl -T
use strict;
use warnings;
use Test::More tests => 15;

require_ok 'Mouse';
require_ok 'Mouse::Util';
require_ok 'Mouse::Tiny';
require_ok 'Mouse::Spec';
require_ok 'Mouse::Role';

my $main_version;

for my $module ( qw( Mouse Mouse::Util Mouse::Tiny Mouse::Spec Mouse::Role ) ){
    $main_version ||= $module->VERSION;
    ok( $module->VERSION =~ /^v/, "Version number should start with 'v' in $module!" );
    ok( $module->VERSION eq $main_version, "Version number mismatch within the same distribution!" );
}


