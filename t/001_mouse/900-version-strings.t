#!perl -T
use strict;
use warnings;
use Test::More;

require_ok 'Mouse';
require_ok 'Mouse::Util';
require_ok 'Mouse::Tiny';
require_ok 'Mouse::Spec';
require_ok 'Mouse::Role';

ok $Mouse::VERSION =~ /^v/, 'Mouse version';

for my $module ( qw( Mouse::Util Mouse::Tiny Mouse::Spec Mouse::Role ) ){
    ok $module->VERSION =~ /^v/, "Version number should start with 'v' in $module!";
    ok $module->VERSION eq $Mouse::VERSION, "Version number mismatch within the same distribution!";
}

done_testing;
