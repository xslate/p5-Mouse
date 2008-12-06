use strict;
use warnings;
use Mouse::Util 'get_linear_isa';
use Test::More tests => 2;

{
    package Parent;
}

{
    package Child;
    use Mouse;
    extends 'Parent';
}

is_deeply get_linear_isa('Parent'), [ 'Parent' ];
is_deeply get_linear_isa('Child'),  [ 'Child', 'Parent' ];

