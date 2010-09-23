#!/usr/bin/perl
use strict;
use warnings;

use Test::More;
use Test::Exception;
my $warn = '';
BEGIN { $SIG{__WARN__} = sub { $warn .= "@_" } }
{
    package Foo;
    use Mouse;

    has foo => ( is => "rw" );

    package Bar;
    sub oink { "oink" }

    package Gorch;
    use Mouse;

    extends qw(Bar Foo);

    ::lives_ok{
        has '+foo' => ( default => "the default" );
    } 'inherit attr when @ISA contains a non Mouse class before a Mouse class with the base attr';
}

{
    my $g = Gorch->new;

    is( $g->foo, "the default", "inherited attribute" );
    is( $g->oink, "oink",       "inherited method from a non-Mouse class");
}

is $warn, '', 'produces no warnings';
done_testing;

