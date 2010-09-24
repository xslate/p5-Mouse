#!/usr/bin/perl

use strict;
use warnings;

use Test::More tests => 7;
use Test::Exception;

use Mouse::Meta::Role::Application::RoleSummation;
use Mouse::Meta::Role::Composite;

{
    package Role::Foo;
    use Mouse::Role;
    has 'foo' => (is => 'rw');

    package Role::Bar;
    use Mouse::Role;
    has 'bar' => (is => 'rw');

    package Role::FooConflict;
    use Mouse::Role;
    has 'foo' => (is => 'rw');

    package Role::BarConflict;
    use Mouse::Role;
    has 'bar' => (is => 'rw');

    package Role::AnotherFooConflict;
    use Mouse::Role;
    with 'Role::FooConflict';
}

# test simple attributes
{
    my $c = Mouse::Meta::Role::Composite->new(
        roles => [
            Role::Foo->meta,
            Role::Bar->meta,
        ]
    );
    isa_ok($c, 'Mouse::Meta::Role::Composite');

    is($c->name, 'Role::Foo|Role::Bar', '... got the composite role name');

    lives_ok {
        Mouse::Meta::Role::Application::RoleSummation->new->apply($c);
    } '... this succeeds as expected';

    is_deeply(
        [ sort $c->get_attribute_list ],
        [ 'bar', 'foo' ],
        '... got the right list of attributes'
    );
}

# test simple conflict
dies_ok {
    Mouse::Meta::Role::Application::RoleSummation->new->apply(
        Mouse::Meta::Role::Composite->new(
            roles => [
                Role::Foo->meta,
                Role::FooConflict->meta,
            ]
        )
    );
} '... this fails as expected';

# test complex conflict
dies_ok {
    Mouse::Meta::Role::Application::RoleSummation->new->apply(
        Mouse::Meta::Role::Composite->new(
            roles => [
                Role::Foo->meta,
                Role::Bar->meta,
                Role::FooConflict->meta,
                Role::BarConflict->meta,
            ]
        )
    );
} '... this fails as expected';

# test simple conflict
dies_ok {
    Mouse::Meta::Role::Application::RoleSummation->new->apply(
        Mouse::Meta::Role::Composite->new(
            roles => [
                Role::Foo->meta,
                Role::AnotherFooConflict->meta,
            ]
        )
    );
} '... this fails as expected';

