#!/usr/bin/env perl
use strict;
use warnings;
use Test::More tests => 10;

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

do {
    my $object = Class->new;

    is_deeply([splice @called], [], "no DEMOLISH calls yet");
};

is_deeply([splice @called], ['Class::DEMOLISH']);

do {
    my $child = Child->new;
    is_deeply([splice @called], [], "no DEMOLISH calls yet");

};

is_deeply([splice @called], ['Child::DEMOLISH', 'Class::DEMOLISH']);

Class->meta->make_immutable();
Child->meta->make_immutable();

is_deeply([splice @called], [], "no DEMOLISH calls yet");

do {
    my $object = Class->new;

    is_deeply([splice @called], [], "no DEMOLISH calls yet");
};

is_deeply([splice @called], ['Class::DEMOLISH'], 'after make_immutable');

do {
    my $child = Child->new;
    is_deeply([splice @called], [], "no DEMOLISH calls yet");

};

is_deeply([splice @called], ['Child::DEMOLISH', 'Class::DEMOLISH'], 'after make_immutable');
