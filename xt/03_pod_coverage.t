#!/usr/bin/perl

use strict;
use warnings;

use Test::More;

plan skip_all => 'TODO';

eval "use Test::Pod::Coverage 1.04";
plan skip_all => "Test::Pod::Coverage 1.04 required for testing POD coverage" if $@;

# This is a stripped down version of all_pod_coverage_ok which lets us
# vary the trustme parameter per module.
my @modules = all_modules();
plan tests => scalar @modules;

my %trustme = (
    'Mouse::Meta::Module' => [
    ],

    'Mouse::Meta::Class'  => [
        qw(
            get_method_body
            superclasses
            clone_instance
         )
    ],
    'Mouse::Meta::Attribute' => [
        qw(
            interpolate_class
            throw_error
            create
            get_parent_args
            verify_type_constraint
            canonicalize_args
            coerce_constraint
         )
    ],
    'Mouse::Meta::Method'                  => [],
    'Mouse::Meta::Method::Accessor'        => [],
    'Mouse::Meta::Method::Constructor'     => [],
    'Mouse::Meta::Method::Destructor'      => [],
    'Mouse::Meta::Role'                    => [],
    'Mouse::Meta::Role::Composite' =>
        [ 'get_method', 'get_method_list', 'has_method', 'add_method' ],
    'Mouse::Role' => [
        qw( after
            around
            augment
            before
            extends
            has
            inner
            override
            super
            with )
    ],
    'Mouse::Meta::TypeConstraint'      => [
        qw(
            compile_type_constraint
            parameterize
        )
    ],
    'Mouse::Util'                      => [
        qw(
            generate_isa_predicate_for
            does dump meta
        )
    ],
    'Mouse::Util::TypeConstraints'     => [
        qw(typecast_constraints)
     ],

    'Mouse::Exporter' => [
        qw(
            do_import do_unimport
        )
    ],
    'Mouse::Spec'         => ['.+'],
    'Squirrel'            => ['.+'],
    'Squirrel::Role'      => ['.+'],
    'Mouse::TypeRegistry' => ['.+'],
);

for my $module ( sort @modules ) {
    my $trustme = [];
    if ( $trustme{$module} ) {
        my $methods = join '|', @{ $trustme{$module} };
        $trustme = [qr/^(?:$methods)$/];
    }

    pod_coverage_ok(
        $module, { trustme => $trustme },
        "Pod coverage for $module"
    );
}
