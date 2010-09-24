#!perl -T
package Foo;
use strict;
use warnings;
use Test::More tests => 2;

require_ok 'Mouse';
require_ok 'Mouse::Role';

no warnings 'uninitialized';

diag "Testing Mouse/$Mouse::VERSION (", exists $INC{'Mouse/PurePerl.pm'} ? 'Pure Perl' : 'XS', ")";

diag "Soft dependency versions:";

eval { require Moose };
diag "    Class::MOP: $Class::MOP::VERSION";
diag "    Moose: $Moose::VERSION";
