#!/usr/bin/env perl
use strict;
use warnings;
use Test::More tests => 6;

my $builder_called = 0;

do {
    package Class;
    use Mouse;

    has name => (
        is       => 'rw',
        isa      => 'Str',
        builder  => '_build_name',
    );

    sub default_name { "Frank" }
    sub _build_name {
        my $self = shift;
        ++$builder_called;
        return uc $self->default_name;
    };
};

my $object = Class->new(name => "Bob");
is($builder_called, 0, "builder not called in the constructor when we pass a value");
is($object->name, "Bob", "builder doesn't matter when we just set the value in constructor");
$object->name("Bill");
is($object->name, "Bill", "builder doesn't matter when we just set the value in writer");
is($builder_called, 0, "builder not called in the setter");
$builder_called = 0;

my $object2 = Class->new;
is($object2->name, "FRANK", "builder called to provide the default value");
is($builder_called, 1, "builder called ONCE to provide the default value");

# XXX: test clearer, lazy
