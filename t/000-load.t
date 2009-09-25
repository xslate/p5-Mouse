#!perl -T
package Foo;
use strict;
use warnings;
use Test::More tests => 1;

use_ok 'Mouse';

no warnings 'uninitialized';

diag "Soft dependency versions:";

eval{ require MRO::Compat };
diag "    MRO::Compat: $MRO::Compat::VERSION";

eval { require Moose };
diag "    Class::MOP: $Class::MOP::VERSION";
diag "    Moose: $Moose::VERSION";

eval { require Class::Method::Modifiers::Fast };
diag "    Class::Method::Modifiers::Fast: $Class::Method::Modifiers::Fast::VERSION";
