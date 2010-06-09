#!/usr/bin/env perl
use strict;
use warnings;
use Test::More;
use Test::Mouse;

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

with_immutable sub {
    my $object = Class->new;

    ok defined($object), $object->meta->is_immutable() ? 'mutable' : 'immutable';

    is_deeply([splice @called], ["Class::BUILD"]);

    my $child = Child->new;

    is_deeply([splice @called], ["Class::BUILD", "Child::BUILD"]);

    $child->BUILDALL({});

    is_deeply([splice @called], ["Class::BUILD", "Child::BUILD"], 'BUILDALL');

    $child = Child->meta->new_object();
    is_deeply([splice @called], ["Class::BUILD", "Child::BUILD"], 'new_object calls BUILDALL');
}, qw(Class Child);

done_testing;
