#!/usr/bin/env perl
use strict;
use warnings;
use Test::More tests => 10;

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

can_ok($attr, qw(name associated_class predicate clearer));
is($attr->name, 'pawn', 'attribute name');
is($attr->associated_class, Class->meta, 'associated_class');
is($attr->predicate, 'has_pawn', 'predicate');
is($attr->clearer, 'clear_pawn', 'clearer');
ok(!$attr->is_lazy_build, "not lazy_build");
is(ref($attr->default), 'CODE', 'default is a coderef');
ok($attr->verify_against_type_constraint(1), 'verify_against_type_constraint works even without isa');
