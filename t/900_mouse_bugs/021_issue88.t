#!perl
use strict;
use Test::More tests => 4;
use Test::Exception;

{
    package Role;
    use Mouse::Role;
    has 'name' =>
        (isa => 'Str', is => 'ro', required => 1);

}

{
    package RoleInitArg;
    use Mouse::Role;
    has 'name' =>
        (isa => 'Str', init_arg => 'Name', is => 'ro', required => 1);

}

{
    package User;
    use Mouse;
    has 'name' =>
        (isa => 'Str', is => 'ro');

    sub BUILD
    {
        my $self = shift;
        Mouse::Util::apply_all_roles($self, 'Role')
    }
}

{
    package UserInitArg;
    use Mouse;
    has 'name' =>
        (isa => 'Str', init_arg => 'Name', is => 'ro');

    sub BUILD
    {
        my $self = shift;
        Mouse::Util::apply_all_roles($self, 'RoleInitArg')
    }
}

package main;

lives_ok { User->new(name => 'Tim') }, 'lives with plain attribute';
lives_ok { UserInitArg->new(Name => 'Tim') }, 'lives with init_arg';
dies_ok  { User->new() }, 'dies without plain attribute';
dies_ok  { UserInitArg->new() }, 'dies without init_arg';
