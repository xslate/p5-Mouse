#!/usr/bin/env perl
use strict;
use warnings;
use Test::More tests => 2;
use Mouse ();

do {
    package My::Meta::Role;
    use Mouse;
    extends 'Mouse::Meta::Role';

    has test_serial => (
        is      => 'ro',
        isa     => 'Int',
        default => 1,
    );

    no Mouse;
};

my $role = My::Meta::Role->create_anon_role;
#use Data::Dumper; $Data::Dumper::Deparse = 1; print Dumper $role->can('test_serial');
is($role->test_serial, 1, "default value for the serial attribute");

my $nine_role = My::Meta::Role->create_anon_role(test_serial => 9);
is($nine_role->test_serial, 9, "parameter value for the serial attribute");

