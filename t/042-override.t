#!/usr/bin/env perl
use strict;
use warnings;
use Test::More tests => 3;
use Test::Exception;

my @parent_calls;
my @child_calls;

do {
    package Parent;
    sub foo { push @parent_calls, [@_] }

    package Child;
    use Mouse;
    extends 'Parent';

    override foo => sub {
        my $self = shift;
        push @child_calls, [splice @_];
        super;
    };
};

Child->foo(10, 11);
is_deeply([splice @parent_calls], [[Child => 10, 11]]);
is_deeply([splice @child_calls], [[10, 11]]);

throws_ok {
    package Orphan; # :(
    use Mouse;
    override foo => sub { };
} qr/^You cannot override 'foo' because it has no super method/;

