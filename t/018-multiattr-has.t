#!/usr/bin/env perl
use strict;
use warnings;
use Test::More tests => 3;

my %trigger;
do {
    package Class;
    use Mouse;

    has [qw/a b c/] => (
        is => 'rw',
        trigger => sub {
            my ($self, $value, $attr) = @_;
            $trigger{$attr->name}++;
        },
    );
};

can_ok(Class => qw/a b c/);
is(Class->meta->attributes, 3, "three attributes created");
Class->new(a => 1, b => 2);

is_deeply(\%trigger, { a => 1, b => 1 }, "correct triggers called");

