#!/usr/bin/env perl
use strict;
use warnings;
use Test::More tests => 15;
use Test::Mouse;

my @called;

do {
    package Class;
    use Mouse;

    sub DEMOLISH {
        push @called, 'Class::DEMOLISH';
    }

#    sub DEMOLISHALL {
#        my $self = shift;
#        push @called, 'Class::DEMOLISHALL';
#        $self->SUPER::DEMOLISHALL(@_);
#    }

    package Child;
    use Mouse;
    extends 'Class';

    sub DEMOLISH {
        push @called, 'Child::DEMOLISH';
    }

#    sub DEMOLISHALL {
#        my $self = shift;
#        push @called, 'Child::DEMOLISHALL';
#        $self->SUPER::DEMOLISHALL(@_);
#    }
};

is_deeply([splice @called], [], "no DEMOLISH calls yet");

with_immutable sub {
    ok(Class->meta, Class->meta->is_immutable ? 'mutable' : 'immutable');

    {
        my $object = Class->new;

        is_deeply([splice @called], [], "no DEMOLISH calls yet");
    }

    is_deeply([splice @called], ['Class::DEMOLISH']);

    {
        my $child = Child->new;
        is_deeply([splice @called], [], "no DEMOLISH calls yet");

    }

    is_deeply([splice @called], ['Child::DEMOLISH', 'Class::DEMOLISH']);

    {
        my $child = Child->new;
        $child->DEMOLISHALL();

        is_deeply([splice @called], ['Child::DEMOLISH', 'Class::DEMOLISH'], 'DEMOLISHALL');
    }

    is_deeply([splice @called], ['Child::DEMOLISH', 'Class::DEMOLISH'], 'DEMOLISHALL');
}, qw(Class Child);
