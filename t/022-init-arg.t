#!/usr/bin/env perl
use strict;
use warnings;
use Test::More tests => 9;

do {
    package Class;
    use Mouse;

    has name => (
        is       => 'rw',
        init_arg => 'key',
        default  => 'default',
    );
};

my $object = Class->new;
is($object->name, 'default', 'accessor uses attribute name');
is($object->{name}, undef, 'nothing in object->{attribute name}!');
is($object->{key}, 'default', 'value is in object->{init_arg}');

my $object2 = Class->new(name => 'name', key => 'key');
is($object2->name, 'key', 'attribute value is from init_arg');
is($object2->{name}, undef, 'no value for the attribute name');
is($object2->{key}, 'key', 'value is from init_arg parameter');

my $attr = $object2->meta->get_attribute('name');
ok($attr, 'got the attribute object by name (not init_arg)');
is($attr->name, 'name', 'name is name');
is($attr->init_arg, 'key', 'init_arg is key');
