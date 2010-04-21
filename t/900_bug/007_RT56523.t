#!/usr/bin/perl
use strict;
use Test::More;
#warn $Mouse::VERSION;
{
    package Foo;

    use Mouse;

    has thing => (
        reader        => 'thing',
        writer        => 'set_thing',
        builder       => '_build_thing',
        lazy          => 1,
    );

    sub _build_thing {
        42;
    }
}

# Get them set
{
    my $obj = Foo->new;
    is $obj->thing, 42;
    $obj->set_thing( 23 );
    is $obj->thing, 23;
}

# Set then get
{
    my $obj = Foo->new;
    $obj->set_thing(23);
    is $obj->thing, 23;
}

done_testing();
