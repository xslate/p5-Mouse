#!/usr/bin/env perl
use strict;
use warnings;
use Test::More tests => 2;
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

