#!/usr/bin/env perl
use strict;
use warnings;
use Test::More tests => 2;

do {
    package Role;
    use Mouse::Role;

    no Mouse::Role;
};

ok(Role->meta, "Role has a meta");
isa_ok(Role->meta, "Mouse::Meta::Role");

