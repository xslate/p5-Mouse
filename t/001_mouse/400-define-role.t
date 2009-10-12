#!/usr/bin/env perl
use strict;
use warnings;
use Test::More tests => 11;
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
} qr/Roles do not support 'extends'/;

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

    has 'foo' => (is => 'bare');

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

TODO: {
    package Role;
    use Mouse::Role;

    eval {
        excludes 'excluded';
    };
    our $TODO;
    local $TODO = "Mouse::Role does not currently support 'excludes'";
    ::ok(!$@, "excludes");

    no Mouse::Role;
};

throws_ok {
    package Role;
    use Mouse::Role;

    confess "Mouse::Role exports confess";

} qr/^Mouse::Role exports confess/;

lives_ok {
    package Role;
    use Mouse::Role;

    my $obj = bless {} => "Impromptu::Class";
    ::is(blessed($obj), "Impromptu::Class");
};

lives_ok{
    package Class;
    use Mouse;

    with 'Role', 'Other::Role';
};

