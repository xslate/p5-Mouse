#!perl -T
use strict;
use warnings;
use Test::More tests => 1;

use_ok 'Mouse';

no warnings 'uninitialized';

diag "Soft dependency versions:";
diag "    MRO::Compat: $MRO::Compat::VERSION";

eval { require Moose };
diag "    Class::MOP: $Class::MOP::VERSION";
diag "    Moose: $Moose::VERSION";

eval { require Class::Method::Modifiers };
diag "    Class::Method::Modifiers: $Class::Method::Modifiers::VERSION";

