use strict;
use warnings;
{
    package My::Role;
    use Mouse::Role;
}
{
    package SomeClass;
    use Mouse -traits => 'My::Role';
}
{
    package SubClassUseBase;
    use base qw/SomeClass/;
}
{
    package SubSubClassUseBase;
    use base qw/SubClassUseBase/;
}

use Test::More tests => 2;
use Mouse::Util qw/find_meta does_role/;

my $subsubclass_meta = Mouse->init_meta( for_class => 'SubSubClassUseBase' );
ok does_role($subsubclass_meta, 'My::Role'),
    'SubSubClass metaclass does role from grandparent metaclass';
my $subclass_meta = find_meta('SubClassUseBase');
ok does_role($subclass_meta, 'My::Role'),
    'SubClass metaclass does role from parent metaclass';
