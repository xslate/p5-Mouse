#!/usr/bin/env perl
use strict;
use warnings;
use Test::More tests => 5;
use Test::Exception;

lives_ok {
    package Role;
    use Mouse::Role;

    no Mouse::Role;
};

throws_ok {
    package Role;
    use Mouse::Role;

    extends 'Role::Parent';

    no Mouse::Role;
} qr/Role does not currently support 'extends'/;

lives_ok {
    package Role;
    use Mouse::Role;

    sub foo {}

    no Mouse::Role;
};

lives_ok {
    package Role;
    use Mouse::Role;

    before foo => sub {};
    after foo  => sub {};
    around foo => sub {};

    no Mouse::Role;
};

lives_ok {
    package Role;
    use Mouse::Role;

    has 'foo';

    no Mouse::Role;
};

do {
    package Other::Role;
    use Mouse::Role;
    no Mouse::Role;
};

lives_ok {
    package Role;
    use Mouse::Role;

    with 'Other::Role';

    no Mouse::Role;
};

