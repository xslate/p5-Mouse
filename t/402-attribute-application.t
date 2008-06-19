#!/usr/bin/env perl
use strict;
use warnings;
use Test::More tests => 5;
use Test::Exception;

do {
    package Role;
    use Mouse::Role;

    has 'attr' => (
        default => 'Role',
    );

    no Mouse::Role;
};

is_deeply(Role->meta->get_attribute('attr'), {default => 'Role'});

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

