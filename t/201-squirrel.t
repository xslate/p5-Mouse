#!/usr/bin/perl

use strict;
use warnings;

use Test::More;
use Scalar::Util 'blessed';

# Don't spew deprecation warnings onto the user's screen
BEGIN {
    $SIG{__WARN__} = sub { warn $_[0] if $_[0] !~ /Squirrel is deprecated/ };
}

do {
    package Foo;
    use Squirrel;

    has foo => (
        isa => "Int",
        is  => "rw",
    );

    no Squirrel;
};

# note that 'Foo' is defined before this, to prevent Moose being loaded from
# affecting its definition

BEGIN {
    plan skip_all => "Moose required for this test" unless eval { require Moose };
    plan tests => 12;
}

do {
    package Bar;
    use Squirrel;

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

eval "
    package Foo;
    use Squirrel;

    has bar => (is => 'rw');
    __PACKAGE__->meta->make_immutable;

    package Bar;
    use Squirrel;

    has bar => (is => 'rw');
    __PACKAGE__->meta->make_immutable;
";
warn $@ if $@;

is(blessed(Foo->meta->get_attribute('foo')), 'Mouse::Meta::Attribute');
is(blessed(Foo->meta->get_attribute('bar')), 'Mouse::Meta::Attribute', 'Squirrel is consistent if Moose was loaded between imports');

is(blessed(Bar->meta->get_attribute('foo')), 'Moose::Meta::Attribute');
is(blessed(Bar->meta->get_attribute('bar')), 'Moose::Meta::Attribute');

