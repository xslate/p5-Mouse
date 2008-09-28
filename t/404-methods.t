#!/usr/bin/env perl
use strict;
use warnings;
use Test::More;
BEGIN {
    if (eval "require Class::Method::Modifiers; 1") {
        plan tests => 1;
    }
    else {
        plan skip_all => "Class::Method::Modifiers required for this test";
    }
}
use Mouse::Util ':test';

my @calls;

do {
    package Role;
    use Mouse::Role;

    sub method {
        push @calls, 'Role::method';
    };

    no Mouse::Role;
};

do {
    package Class;
    use Mouse;
    with 'Role';

    no Mouse;
};

Class->method;
is_deeply([splice @calls], [
    'Role::method',
]);

