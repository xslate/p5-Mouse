#!/usr/bin/env perl
use strict;
use warnings;
use Test::More;
use Mouse ();

my $role = Mouse::Meta::Role->create_anon_role(
    attributes => {
        is_worn => {
            is => 'rw',
            isa => 'Bool',
        },
    },
    methods => {
        remove => sub { shift->is_worn(0) },
    },
);

my $class = Mouse::Meta::Class->create('MyItem::Armor::Helmet');
$role->apply($class);
# XXX: Mouse::Util::apply_all_roles doesn't cope with references yet

my $visored = $class->new_object(is_worn => 0);
ok(!$visored->is_worn, "attribute, accessor was consumed");
$visored->is_worn(1);
ok($visored->is_worn, "accessor was consumed");
$visored->remove;
ok(!$visored->is_worn, "method was consumed");

like($role->name, qr/::__ANON__::/, "");
ok($role->is_anon_role, "the role knows it's anonymous");

ok(Mouse::Util::is_class_loaded(Mouse::Meta::Role->create_anon_role->name), "creating an anonymous role satisifes is_class_loaded");
ok(Mouse::Util::class_of(Mouse::Meta::Role->create_anon_role->name), "creating an anonymous role satisifes class_of");

done_testing;
