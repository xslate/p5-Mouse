#!/usr/bin/env perl
use strict;
use warnings;
use Test::More tests => 20;

do {
    package Class;
    use Mouse;

    has name => (
        is       => 'rw',
        isa      => 'Str',
        init_arg => 'key',
        default  => 'default',
    );

    has no_init_arg => (
        is       => 'rw',
        isa      => 'Str',
        init_arg => undef,
        default  => 'default',
    );

};

for('mutable', 'immutable'){
    my $object = Class->new;
    is($object->name, 'default', "accessor uses attribute name ($_)");
    is($object->{key}, undef, 'nothing in object->{init_arg}!');
    is($object->{name}, 'default', 'value is in object->{name}');

    my $object2 = Class->new(name => 'name', key => 'key');
    is($object2->name, 'key', 'attribute value is from name');
    is($object2->{key}, undef, 'no value for the init_arg');
    is($object2->{name}, 'key', 'value is in key from name');

    my $attr = $object2->meta->get_attribute('name');
    ok($attr, 'got the attribute object by name (not init_arg)');
    is($attr->name, 'name', 'name is name');
    is($attr->init_arg, 'key', 'init_arg is key');

    my $object3 = Class->new(no_init_arg => 'joe');
    is($object3->no_init_arg, 'default', 'init_arg => undef ignores attribute name in the constructor');

    Class->meta->make_immutable;
}
