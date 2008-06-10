#!/usr/bin/env perl
use strict;
use warnings;
use Test::More tests => 9;

do {
    package Class;
    use Mouse;

    has pawn => (
        is        => 'rw',
        predicate => 'has_pawn',
        clearer   => 'clear_pawn',
        default   => sub { 10 },
    );

    no Mouse;
};

my $meta = Class->meta;
isa_ok($meta, 'Mouse::Meta::Class');

my $attr = $meta->get_attribute('pawn');
isa_ok($attr, 'Mouse::Meta::Attribute');

can_ok($attr, qw(name class predicate clearer));
is($attr->name, 'pawn', 'attribute name');
is($attr->class, 'Class', 'attached class');
is($attr->predicate, 'has_pawn', 'predicate');
is($attr->clearer, 'clear_pawn', 'clearer');
is(ref($attr->default), 'CODE', 'default is a coderef');
ok($attr->verify_type_constraint(1), 'verify_type_constraint works even without isa');
