#!/usr/bin/env perl
use strict;
use warnings;
use Test::More tests => 20;

my $builder_called = 0;
my $lazy_builder_called = 0;

do {
    package Class;
    use Mouse;

    has name => (
        is       => 'rw',
        isa      => 'Str',
        builder  => '_build_name',
    );

    sub _build_name {
        my $self = shift;
        ++$builder_called;
        return "FRANK";
    };

    has age => (
        is      => 'ro',
        isa     => 'Int',
        builder => '_build_age',
        lazy    => 1,
        clearer => 'clear_age',
    );

    sub default_age { 20 }
    sub _build_age {
        my $self = shift;
        ++$lazy_builder_called;
        return $self->default_age;
    };

};

# eager builder
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

# lazy builder
my $object3 = Class->new;
is($lazy_builder_called, 0, "lazy builder not called yet");
is($object3->age, 20, "lazy builder value");
is($lazy_builder_called, 1, "lazy builder called on get");
is($object3->age, 20, "lazy builder value");
is($lazy_builder_called, 1, "lazy builder not called on subsequent gets");

$object3->clear_age;
is($lazy_builder_called, 1, "lazy builder not called on clear");
is($object3->age, 20, "lazy builder value");
is($lazy_builder_called, 2, "lazy builder called on get after clear");

$lazy_builder_called = 0 ;
my $object4 = Class->new(age => 50);
is($lazy_builder_called, 0, "lazy builder not called yet");
is($object4->age, 50, "value from constructor");
is($lazy_builder_called, 0, "lazy builder not called if value is from constructor");

$object4->clear_age;
is($lazy_builder_called, 0, "lazy builder not called on clear");
is($object4->age, 20, "lazy builder value");
is($lazy_builder_called, 1, "lazy builder called on get after clear");
