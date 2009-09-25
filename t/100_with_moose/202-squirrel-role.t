#!/usr/bin/perl

use strict;
use warnings;

use Test::More;

use Mouse::Spec;

use Scalar::Util 'blessed';

BEGIN {
    $SIG{__WARN__} = sub { warn $_[0] if $_[0] !~ /Squirrel is deprecated/ };
}

do {
    package Foo::Role;
    use Squirrel::Role; # loa Mouse::Role

    has foo => (
        isa => "Int",
        is  => "rw",
    );

    no Squirrel::Role;
};

# note that 'Foo' is defined before this, to prevent Moose being loaded from
# affecting its definition

BEGIN {
    eval{ require Moose::Role && Moose::Role->VERSION(Mouse::Spec->MooseVersion) };
    plan skip_all => "Moose $Mouse::Spec::MooseVersion required for this test" if $@;
    plan tests => 6;
}

do {
    package Bar::Role;
    use Squirrel::Role; # load Moose::Role

    has foo => (
        isa => "Int",
        is  => "rw",
    );

    no Squirrel::Role;
};

ok(!Foo::Role->can('has'), "Mouse::Role::has was unimported");
ok(!Bar::Role->can('has'), "Moose::Role::has was unimported");

eval q{
    package Foo::Role;
    use Squirrel::Role;

    has bar => (is => 'rw');

    package Bar::Role;
    use Squirrel::Role;

    has bar => (is => 'rw');
};

isa_ok(Foo::Role->meta, 'Mouse::Meta::Role');
isa_ok(Foo::Role->meta, 'Mouse::Meta::Role');

isa_ok(Bar::Role->meta, 'Moose::Meta::Role');
isa_ok(Bar::Role->meta, 'Moose::Meta::Role');

