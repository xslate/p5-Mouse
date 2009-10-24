use strict;
use warnings;
use Test::More tests => 2;

{
    package Parent;
    use Mouse;
}

{
    package Child;
    use Mouse;
    extends 'Parent';
}

is_deeply join(', ', Parent->meta->linearized_isa), 'Parent, Mouse::Object';
is_deeply join(', ', Child->meta->linearized_isa),  'Child, Parent, Mouse::Object';

