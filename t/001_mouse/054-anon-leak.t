#!perl
# This is based on Class-MOP/t/312_anon_class_leak.t
use strict;
use warnings;
use Test::More;

BEGIN {
    eval "use Test::LeakTrace 0.10;";
    plan skip_all => "Test::LeakTrace 0.10 is required for this test" if $@;
}

plan tests => 6;

use Mouse ();
{
    package MyRole;
    use Mouse::Role;

    sub my_role_method{ }
}

# 5.10.0 has a bug on weaken($hash_ref) which leaks an AV.
my $expected = ( $] == 5.010_000 ? 1 : 0 );

leaks_cmp_ok {
    Mouse::Meta::Class->create_anon_class();
} '<=', $expected, 'create_anon_class()';

leaks_cmp_ok {
    Mouse::Meta::Class->create_anon_class(superclasses => ['Mouse::Meta::Class']);
} '<=', $expected, 'create_anon_class() with superclasses';

leaks_cmp_ok {
    Mouse::Meta::Class->create_anon_class(attributes => [
        Mouse::Meta::Attribute->new('foo', is => 'bare'),
    ]);
} '<=', $expected, 'create_anon_class() with attributes';

leaks_cmp_ok {
    Mouse::Meta::Class->create_anon_class(roles => [qw(MyRole)]);
} '<=', $expected, 'create_anon_class() with roles';


leaks_cmp_ok {
    Mouse::Meta::Role->create_anon_role();
} '<=', $expected, 'create_anon_role()';

if($] < 5.010){
    $expected = 2; # in MRO::Compat::get_linear_isa, maybe harmless
}
leaks_cmp_ok {
    Mouse::Meta::Role->create_anon_role(roles => [qw(MyRole)]);
} '<=', $expected, 'create_anon_role() with roles';

