#!/usr/bin/env perl
use strict;
use warnings;
use Test::More tests => 5;

do {
    package Role;
    use Mouse::Role;

    no Mouse::Role;
};

ok(Role->meta, "Role has a meta");
isa_ok(Role->meta, "Mouse::Meta::Role");

is(Role->meta->name, "Role");

ok(!Role->meta->has_attribute('attr'), "Role doesn't have attr attribute yet");

do {
    package Role;
    use Mouse::Role;

    has 'attr';

    no Mouse::Role;
};

ok(Role->meta->has_attribute('attr'), "Role has an attr now");
