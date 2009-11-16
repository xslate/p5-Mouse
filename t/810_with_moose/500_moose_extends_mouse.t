#!/usr/bin/perl

use strict;
use warnings;

use Test::More skip_all => '[TODO] a Moose class cannot extends a Mouse class';

use Mouse::Spec;
BEGIN {
    eval{ require Moose && Moose->VERSION(Mouse::Spec->MooseVersion) };
    plan skip_all => "Moose $Mouse::Spec::MooseVersion required for this test" if $@;
    plan tests => 27;
}

use Test::Exception;

{
    package Foo;
    use Mouse;

    has foo => (
        isa => "Int",
        is  => "rw",
    );

    package Bar;
    use Moose;

    ::lives_ok { extends qw(Foo) } "extend Mouse class with Moose";

    ::lives_ok {
        has bar => (
            isa => "Str",
            is  => "rw",
        );
    } "new attr in subclass";

    package Gorch;
    use Moose;

    ::lives_ok { extends qw(Foo) } "extend Mouse class with Moose";

    {
        local our $TODO = "Moose not yet aware of Mouse meta";
        ::lives_ok {
            has '+foo' => (
                default => 3,
            );
        } "clone and inherit attr in subclass";
    }

    package Quxx;
    use Mouse;

    has quxx => (
        is => "rw",
        default => "lala",
    );

    package Zork;
    use Moose;

    ::lives_ok { extends qw(Quxx) } "extend Mouse class with Moose";

    has zork => (
        is => "rw",
        default => 42,
    );
}

can_ok( Bar => "new" );

my $bar = eval { Bar->new };

ok( $bar, "got an object" );
isa_ok( $bar, "Bar" );
isa_ok( $bar, "Foo" );

can_ok( $bar, qw(foo bar) );

is( eval { $bar->foo }, undef, "no default value" );
is( eval { $bar->bar }, undef, "no default value" );

{
    local $TODO = "Moose not yet aware of Mouse meta";

    is_deeply(
        [ sort map { $_->name } Bar->meta->get_all_attributes ],
        [ sort qw(foo bar) ],
        "attributes",
    );

    is( eval { Gorch->new->foo }, 3, "cloned and inherited attr's default" );
}

can_ok( Zork => "new" );

{
    my $zork = eval { Zork->new };

    ok( $zork, "got an object" );
    isa_ok( $zork, "Zork" );
    isa_ok( $zork, "Quxx" );

    can_ok( $zork, qw(quxx zork) );

    local $TODO = "Constructor needs to know default values of attrs from both";
    is( eval { $bar->quxx }, "lala", "default value" );
    is( eval { $bar->zork }, 42,     "default value" );
}

{
    my $zork = eval { Zork->new( zork => "diff", quxx => "blah" ) };

    ok( $zork, "got an object" );
    isa_ok( $zork, "Zork" );
    isa_ok( $zork, "Quxx" );

    can_ok( $zork, qw(quxx zork) );

    local $TODO = "Constructor needs to know init args of attrs from both";
    is( eval { $bar->quxx }, "blah", "constructor param" );
    is( eval { $bar->zork }, "diff", "constructor param" );
}
