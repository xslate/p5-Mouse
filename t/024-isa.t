#!/usr/bin/env perl
use strict;
use warnings;
use Test::More;
use Test::Exception;

my %values_for_type = (
    Any => {
        valid   => [
            undef,
            \undef,
            1.0,
            "foo",
            \"foo",
            sub { die },
            qr/^1?$|^(11+?)\1+$/,
            [],
            {},
            \do { my $v },
            Test::Builder->new,
        ],
        invalid => [],
    },

    Item => {
        #valid   => [], # populated later with the values from Any
        invalid => [],
    },

    Bool => {
        valid   => [undef, "", 1, 0, "1", "0"],
        invalid => [1.5, "true", "false", "t", "f", ],
    },

    Undef => {
        valid   => [],
        invalid => [],
    },

    Defined => {
        valid   => [],
        invalid => [],
    },

    Value => {
        valid   => [],
        invalid => [],
    },

    Num => {
        valid   => [],
        invalid => [],
    },

    Int => {
        valid   => [],
        invalid => [],
    },

    Str => {
        valid   => [],
        invalid => [],
    },

    ClassName => {
        valid   => [],
        invalid => [],
    },

    Ref => {
        valid   => [],
        invalid => [],
    },

    ScalarRef => {
        valid   => [],
        invalid => [],
    },

    ArrayRef => {
        valid   => [],
        invalid => [],
    },

    HashRef => {
        valid   => [],
        invalid => [],
    },

    CodeRef => {
        valid   => [],
        invalid => [],
    },

    RegexpRef => {
        valid   => [],
        invalid => [],
    },

    GlobRef => {
        valid   => [],
        invalid => [],
    },

    FileHandle => {
        valid   => [],
        invalid => [],
    },

    Object => {
        valid   => [],
        invalid => [],
    },
);

$values_for_type{Item}{valid} = $values_for_type{Any}{valid};

my $plan = 0;
$plan += 5 * @{ $values_for_type{$_}{valid} }   for keys %values_for_type;
$plan += 4 * @{ $values_for_type{$_}{invalid} } for keys %values_for_type;
$plan++; # can_ok

plan tests => $plan;

do {
    package Class;
    use Mouse;

    for my $type (keys %values_for_type) {
        has $type => (
            is  => 'rw',
            isa => $type,
        );
    }
};

can_ok(Class => keys %values_for_type);

for my $type (keys %values_for_type) {
    for my $value (@{ $values_for_type{$type}{valid} }) {
        lives_ok {
            my $via_new = Class->new($type => $value);
            is_deeply($via_new->$type, $value, "correctly set a $type in the constructor");
        };

        lives_ok {
            my $via_set = Class->new;
            is($via_set->$type, undef, "initially unset");
            $via_set->$type($value);
            is_deeply($via_set->$type, $value, "correctly set a $type in the setter");
        };
    }

    for my $value (@{ $values_for_type{$type}{invalid} }) {
        my $via_new;
        throws_ok {
            $via_new = Class->new($type => $value);
        } qr/Attribute \($type\) does not pass the type constraint because: Validation failed for '$type' failed with value \Q$value\E/;
        is($via_new, undef, "no object created");

        my $via_set = Class->new;
        throws_ok {
            $via_set->$type($value);
        } qr/Attribute \($type\) does not pass the type constraint because: Validation failed for '$type' failed with value \Q$value\E/;

        is($via_set->$type, undef, "value for $type not set");
    }
}

