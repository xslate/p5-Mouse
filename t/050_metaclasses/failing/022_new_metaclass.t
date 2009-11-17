#!/usr/bin/env perl
use strict;
use warnings;
use Test::More tests => 2;

do {
    package My::Meta::Class;
    use Mouse;
    BEGIN { extends 'Mouse::Meta::Class' };

    package Mouse::Meta::Class::Custom::MyMetaClass;
    sub register_implementation { 'My::Meta::Class' }
};

do {
    package My::Class;
    use Mouse -metaclass => 'My::Meta::Class';
};

do {
    package My::Class::Aliased;
    use Mouse -metaclass => 'MyMetaClass';
};

is(My::Class->meta->meta->name, 'My::Meta::Class');
is(My::Class::Aliased->meta->meta->name, 'My::Meta::Class');

