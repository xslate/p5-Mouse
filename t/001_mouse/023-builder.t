#!/usr/bin/env perl
use strict;
use warnings;
use Test::More tests => 47;
use Test::Exception;

my $builder_called = 0;
my $lazy_builder_called = 0;

do {
    package Class;
    use Mouse;

    has name => (
        is        => 'rw',
        isa       => 'Str',
        builder   => '_build_name',
        predicate => 'has_name',
        clearer   => 'clear_name',
    );

    sub _build_name {
        my $self = shift;
        ++$builder_called;
        return "FRANK";
    };

    has age => (
        is         => 'ro',
        isa        => 'Int',
        lazy_build => 1,
        clearer    => 'clear_age',
        predicate  => 'has_age',
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
ok($object->has_name, "predicate: value from constructor");
is($builder_called, 0, "builder not called in the constructor when we pass a value");
is($object->name, "Bob", "builder doesn't matter when we just set the value in constructor");
$object->name("Bill");
is($object->name, "Bill", "builder doesn't matter when we just set the value in writer");
is($builder_called, 0, "builder not called in the setter");
$builder_called = 0;

$object->clear_name;
ok(!$object->has_name, "predicate: no value after clear");
is($object->name, undef, "eager builder does NOT swoop in after clear");
ok(!$object->has_name, "predicate: no value after clear and get");
is($builder_called, 0, "builder not called in the getter, even after clear");
$builder_called = 0;

my $object2 = Class->new;
ok($object2->has_name, "predicate: value from eager builder");
is($object2->name, "FRANK", "builder called to provide the default value");
is($builder_called, 1, "builder called ONCE to provide the default value");

# lazy builder
my $object3 = Class->new;
is($lazy_builder_called, 0, "lazy builder not called yet");
ok(!$object3->has_age, "predicate: no age yet");
is($object3->age, 20, "lazy builder value");
ok($object3->has_age, "predicate: have value after get");
is($lazy_builder_called, 1, "lazy builder called on get");
is($object3->age, 20, "lazy builder value");
is($lazy_builder_called, 1, "lazy builder not called on subsequent gets");
ok($object3->has_age, "predicate: have value after subsequent gets");

$lazy_builder_called = 0;
$object3->clear_age;
ok(!$object3->has_age, "predicate: no value after clear");
is($lazy_builder_called, 0, "lazy builder not called on clear");
is($object3->age, 20, "lazy builder value");
ok($object3->has_age, "predicate: have value after clear and get");
is($lazy_builder_called, 1, "lazy builder called on get after clear");

$lazy_builder_called = 0;
my $object4 = Class->new(age => 50);
ok($object4->has_age, "predicate: have value from constructor");
is($lazy_builder_called, 0, "lazy builder not called yet");
is($object4->age, 50, "value from constructor");
is($lazy_builder_called, 0, "lazy builder not called if value is from constructor");

$object4->clear_age;
ok(!$object4->has_age, "predicate: no value after clear");
is($lazy_builder_called, 0, "lazy builder not called on clear");
is($object4->age, 20, "lazy builder value");
ok($object4->has_age, "predicate: have value after clear and get");
is($lazy_builder_called, 1, "lazy builder called on get after clear");

do {
    package Class::Error;
    use Mouse;

    ::throws_ok {
        has error => (
            lazy_build => 1,
            default => 1,
        );
    } qr/You can not use lazy_build and default for the same attribute \(error\)/;
};

my @calls;
do {
    package Class::CustomBuilder;
    use Mouse;

    has custom => (
        is => 'ro',
        lazy_build => 1,
        builder    => 'build_my_customs',
        predicate  => 'has_my_customs',
        clearer    => 'clear_my_customs',
    );

    sub build_my_customs {
        push @calls, 'build_my_customs';
        return 'yo';
    }
};

my $cb = Class::CustomBuilder->new;
ok(!$cb->has_my_customs, "correct predicate");
is($cb->custom, 'yo');
is_deeply([splice @calls], ['build_my_customs']);
ok($cb->has_my_customs, "correct predicate");
ok($cb->clear_my_customs, "correct clearer");
ok(!$cb->has_my_customs, "correct predicate");

do {
    package Class::UnderscoreBuilder;
    use Mouse;

    has _attr => (
        is => 'ro',
        lazy_build => 1,
    );

    sub _build__attr {
        push @calls, '_build__attr';
        return 'ping';
    }
};

my $cub = Class::UnderscoreBuilder->new;
ok(!$cub->_has_attr, "correct predicate");
is($cub->_attr, 'ping');
is_deeply([splice @calls], ['_build__attr']);
ok($cub->_has_attr, "correct predicate");
ok($cub->_clear_attr, "correct clearer");
ok(!$cub->_has_attr, "correct predicate");

