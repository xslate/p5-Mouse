use strict;
use warnings;
use Mouse::Util 'get_linear_isa';
use Test::More tests => 2;

{
    package Parent;
}

{
    package Child;
    unshift @Child::ISA, 'Parent';
}

is_deeply join(', ', @{get_linear_isa('Parent')}), 'Parent';
is_deeply join(', ', @{get_linear_isa('Child')}),  'Child, Parent';

