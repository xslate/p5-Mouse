#!/usr/bin/env perl
use strict;
use warnings;
use Test::More tests => 12;

my ($class_build, $child_build) = (0, 0);
my ($class_buildall, $child_buildall) = (0, 0);

do {
    package Class;
    use Mouse;

    sub BUILD {
        ++$class_build;
    }

    sub BUILDALL {
        my $self = shift;
        ++$class_buildall;
        $self->SUPER::BUILDALL(@_);
    }

    package Child;
    use Mouse;
    extends 'Class';

    sub BUILD {
        ++$child_build;
    }

    sub BUILDALL {
        my $self = shift;
        ++$child_buildall;
        $self->SUPER::BUILDALL(@_);
    }


};

is($class_build, 0, "no calls to Class->BUILD");
is($child_build, 0, "no calls to Child->BUILD");

is($class_buildall, 0, "no calls to Class->BUILDALL");
is($child_buildall, 0, "no calls to Child->BUILDALL");

my $object = Class->new;

is($class_build, 1, "Class->new calls Class->BUILD");
is($child_build, 0, "Class->new does not call Child->BUILD");

is($class_buildall, 1, "Class->new calls Class->BUILDALL");
is($child_buildall, 0, "no calls to Child->BUILDALL");

my $child = Child->new;

is($child_build, 1, "Child->new calls Child->BUILD");
is($class_build, 2, "Child->new also calls Class->BUILD");

is($child_buildall, 1, "Child->new calls Child->BUILDALL");
is($class_buildall, 2, "Child->BUILDALL calls Class->BUILDALL (but not Child->new)");

