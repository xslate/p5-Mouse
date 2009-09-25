#!/usr/bin/perl

use strict;
use warnings;

use Test::More;

use Mouse::Spec;

use Scalar::Util 'blessed';

# Don't spew deprecation warnings onto the user's screen
BEGIN {
    $SIG{__WARN__} = sub { warn $_[0] if $_[0] !~ /Squirrel is deprecated/ };
}

do {
    package Foo;
    use Squirrel; # load Mouse

    has foo => (
        isa => "Int",
        is  => "rw",
    );

    no Squirrel;
};

# note that 'Foo' is defined before this, to prevent Moose being loaded from
# affecting its definition
BEGIN {
    eval{ require Moose && Moose->VERSION(Mouse::Spec->MooseVersion) };
    plan skip_all => "Moose $Mouse::Spec::MooseVersion required for this test" if $@;
    plan tests => 12;
}

do {
    package Bar;
    use Squirrel; # load Moose

    has foo => (
        isa => "Int",
        is  => "rw",
    );

    no Squirrel;
};

my $foo = Foo->new(foo => 3);
isa_ok($foo, "Foo");
isa_ok($foo, "Mouse::Object");
is($foo->foo, 3, "accessor");

my $bar = Bar->new(foo => 3);
isa_ok($bar, "Bar");
isa_ok($bar, "Moose::Object");
is($bar->foo, 3, "accessor");

ok(!Foo->can('has'), "Mouse::has was unimported");
ok(!Bar->can('has'), "Moose::has was unimported");

eval q{
    package Foo;
    use Squirrel;

    has bar => (is => 'rw');
    __PACKAGE__->meta->make_immutable;

    package Bar;
    use Squirrel;

    has bar => (is => 'rw');
    __PACKAGE__->meta->make_immutable;
};
warn $@ if $@;

is(blessed(Foo->meta->get_attribute('foo')), 'Mouse::Meta::Attribute');
is(blessed(Foo->meta->get_attribute('bar')), 'Mouse::Meta::Attribute', 'Squirrel is consistent if Moose was loaded between imports');

is(blessed(Bar->meta->get_attribute('foo')), 'Moose::Meta::Attribute');
is(blessed(Bar->meta->get_attribute('bar')), 'Moose::Meta::Attribute');

