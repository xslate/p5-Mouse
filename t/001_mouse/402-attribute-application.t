#!/usr/bin/env perl
use strict;
use warnings;
use Test::More tests => 11;
use Test::Exception;

do {
    package Role;
    use Mouse::Role;

    has 'attr' => (
        is      => 'bare',
        default => 'Role',
    );

    no Mouse::Role;
};

is(Role->meta->get_attribute('attr')->{default}, 'Role');

do {
    package Class;
    use Mouse;
    with 'Role';

    no Mouse;
};

ok(Class->meta->has_attribute('attr'), "role application added the attribute");
is(Class->meta->get_attribute('attr')->default, 'Role');

do {
    package Role2;
    use Mouse::Role;

    has 'attr' => (
        is      => 'bare',
        default => 'Role2',
    );

    no Mouse::Role;
};

lives_ok {
    package Class2;
    use Mouse;
    with 'Role';
    with 'Role2';
};

is(Class2->meta->get_attribute('attr')->default, 'Role');

lives_ok {
    package Class3;
    use Mouse;

    with 'Role';

    has attr => (
        is      => 'bare',
        default => 'Class3',
    );
};

is(Class3->meta->get_attribute('attr')->default, 'Class3');

lives_ok {
    package Class::Parent;
    use Mouse;

    has attr => (
        is      => 'bare',
        default => 'Class::Parent',
    );
};

is(Class::Parent->meta->get_attribute('attr')->default, 'Class::Parent', 'local class wins over the role');

lives_ok {
    package Class::Child;
    use Mouse;

    extends 'Class::Parent';

    with 'Role';
};

is(Class::Child->meta->get_attribute('attr')->default, 'Role', 'role wins over the parent method');
