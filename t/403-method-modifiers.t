#!/usr/bin/env perl
use strict;
use warnings;
use Test::More tests => 4;
use Test::Exception;

my @calls;
my ($before, $after, $around);

do {
    package Role;
    use Mouse::Role;

    $before = sub {
        push @calls, 'Role::foo:before';
    };
    before foo => $before;

    $after = sub {
        push @calls, 'Role::foo:after';
    };
    after foo => $after;

    $around = sub {
        my $orig = shift;
        push @calls, 'Role::foo:around_before';
        $orig->(@_);
        push @calls, 'Role::foo:around_after';
    };
    around foo => $around;

    no Mouse::Role;
};

is_deeply([Role->meta->get_before_method_modifiers('foo')], [$before]);
is_deeply([Role->meta->get_after_method_modifiers('foo')],  [$after]);
is_deeply([Role->meta->get_around_method_modifiers('foo')], [$around]);

do {
    package Class;
    use Mouse;
    with 'Role';

    sub foo {
        push @calls, 'Class::foo';
    }

    no Mouse;
};

Class->foo;
is_deeply([splice @calls], [
    'Role::foo:before',
    'Role::foo:around_before',
    'Class::foo',
    'Role::foo:around_after',
    'Role::foo:after',
]);

