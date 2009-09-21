#!/usr/bin/perl

use strict;
use warnings;

use Test::More tests => 14;
use Test::Exception;

use Mouse::Meta::Role::Application::RoleSummation;
use Mouse::Meta::Role::Composite;

{
    package Role::Foo;
    use Mouse::Role;

    package Role::Bar;
    use Mouse::Role;

    package Role::Baz;
    use Mouse::Role;

    package Role::Gorch;
    use Mouse::Role;
}

{
    my $c = Mouse::Meta::Role::Composite->new(
        roles => [
            Role::Foo->meta,
            Role::Bar->meta,
            Role::Baz->meta,
        ]
    );
    isa_ok($c, 'Mouse::Meta::Role::Composite');

    is($c->name, 'Role::Foo|Role::Bar|Role::Baz', '... got the composite role name');

    is_deeply($c->get_roles, [
        Role::Foo->meta,
        Role::Bar->meta,
        Role::Baz->meta,
    ], '... got the right roles');

    ok($c->does_role($_), '... our composite does the role ' . $_)
        for qw(
            Role::Foo
            Role::Bar
            Role::Baz
        );

    lives_ok {
        Mouse::Meta::Role::Application::RoleSummation->new->apply($c);
    } '... this composed okay';

    ##... now nest 'em
    {
        my $c2 = Mouse::Meta::Role::Composite->new(
            roles => [
                $c,
                Role::Gorch->meta,
            ]
        );
        isa_ok($c2, 'Mouse::Meta::Role::Composite');

        is($c2->name, 'Role::Foo|Role::Bar|Role::Baz|Role::Gorch', '... got the composite role name');

        is_deeply($c2->get_roles, [
            $c,
            Role::Gorch->meta,
        ], '... got the right roles');

        ok($c2->does_role($_), '... our composite does the role ' . $_)
            for qw(
                Role::Foo
                Role::Bar
                Role::Baz
                Role::Gorch
            );
    }
}
