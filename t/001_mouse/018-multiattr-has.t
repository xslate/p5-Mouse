#!/usr/bin/env perl
use strict;
use warnings;
use Test::More tests => 3;

my %trigger;
do {
    package Class;
    use Mouse;

    for my $attr (qw/a b c/) {
        has $attr => (
            is => 'rw',
            trigger => sub {
                $trigger{$attr}++;
            },
        );
    }
};

can_ok(Class => qw/a b c/);
is_deeply([sort Class->meta->get_attribute_list], [sort qw/a b c/], "three attributes created");
Class->new(a => 1, b => 2);

is_deeply(\%trigger, { a => 1, b => 1 }, "correct triggers called");

