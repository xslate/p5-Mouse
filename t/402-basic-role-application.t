#!/usr/bin/env perl
use strict;
use warnings;
use Test::More tests => 1;

do {
    package Role;
    use Mouse::Role;

    has 'attr';

    no Mouse::Role;
};

do {
    package Class;
    use Mouse;
    with 'Role';

    no Mouse;
};

ok(Class->meta->has_attribute('attr'), "role application added the attribute");

