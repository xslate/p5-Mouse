use strict;
use warnings;
use Test::More tests => 6;

{
    package MouseClass;
    use Carp; # import external functions (not our methods)
    use Mouse;
    sub foo { }
    no Mouse;
}
{
    package MouseClassImm;
    use Carp; # import external functions (not our methods)
    use Mouse;
    sub foo { }
    no Mouse;
    __PACKAGE__->meta->make_immutable();
}
{
    package MouseRole;
    use Carp; # import external functions (not our methods)
    use Mouse::Role;
    sub bar { }
    no Mouse::Role;
}
{
    package MouseRoleWithoutNoMouseRole;
    use Mouse::Role;

    sub baz { }
    # without no Mouse::Role;
}
{
    package MouseClassWithRole;
    use Mouse;

    with 'MouseRole';
    no Mouse;
}
{
    package MouseClassWithRoles;
    use Mouse;

    with qw(MouseRole MouseRoleWithoutNoMouseRole);
}

is join(',', sort MouseClass->meta->get_method_list()),    'foo,meta',             "mutable Mouse";
is join(',', sort MouseClassImm->meta->get_method_list()), 'DESTROY,foo,meta,new', "immutable Mouse";

is join(',', sort MouseRole->meta->get_method_list()),     'bar,meta',             "role Mouse";
is join(',', sort MouseRoleWithoutNoMouseRole->meta->get_method_list()),
                                                           'baz,meta',             "role Mouse";

is join(',', sort MouseClassWithRole->meta->get_method_list()),
                                                           'bar,meta',                 "Mouse with a role";
is join(',', sort MouseClassWithRoles->meta->get_method_list()),
                                                           'bar,baz,meta',                 "Mouse with roles";


