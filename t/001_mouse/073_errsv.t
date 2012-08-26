#!perl
# https://rt.cpan.org/Ticket/Display.html?id=75313
use strict;
use Test::More tests => 1;

{
    package Foo;
    use Mouse;
    sub BUILD {
        $@ = "foo";
        #use Devel::Peek; Dump $@;
        my $x = $@;
        #use Devel::Peek; Dump $@;
        ::is $@, "foo";
    }
}

Foo->new;

done_testing;

