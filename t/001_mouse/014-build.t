#!/usr/bin/env perl
use strict;
use warnings;
use Test::More tests => 5;

my @called;

do {
    package Class;
    use Mouse;

    sub BUILD {
        push @called, 'Class::BUILD';
    }

#    sub BUILDALL {
#        my $self = shift;
#        push @called, 'Class::BUILDALL';
#        $self->SUPER::BUILDALL(@_);
#    }

    package Child;
    use Mouse;
    extends 'Class';

    sub BUILD {
        push @called, 'Child::BUILD';
    }

#    sub BUILDALL {
#        my $self = shift;
#        push @called, 'Child::BUILDALL';
#        $self->SUPER::BUILDALL(@_);
#    }
};

is_deeply([splice @called], [], "no BUILD calls yet");

my $object = Class->new;

is_deeply([splice @called], ["Class::BUILD"]);

my $child = Child->new;

is_deeply([splice @called], ["Class::BUILD", "Child::BUILD"]);

Class->meta->make_immutable;
Child->meta->make_immutable;

$object = Class->new;

is_deeply([splice @called], ["Class::BUILD"], 'after make_immutable');

$child = Child->new;

is_deeply([splice @called], ["Class::BUILD", "Child::BUILD"], 'after make_immutable');

