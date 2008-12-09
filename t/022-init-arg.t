#!/usr/bin/env perl
use strict;
use warnings;
use Test::More tests => 11;

do {
    package Class;
    use Mouse;

    has name => (
        is       => 'rw',
        isa      => 'Str',
        init_arg => 'key',
        default  => 'default',
    );
};

my $object = Class->new;
is($object->name, 'default', 'accessor uses attribute name');
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

do {
    package Foo;
    use Mouse;

    has name => (
        is       => 'rw',
        init_arg => undef,
        default  => 'default',
    );
};

my $foo = Foo->new(name => 'joe');
is($foo->name, 'default', 'init_arg => undef ignores attribute name in the constructor');

Foo->meta->make_immutable;

my $bar = Foo->new(name => 'joe');
is($bar->name, 'default', 'init_arg => undef ignores attribute name in the inlined constructor');
