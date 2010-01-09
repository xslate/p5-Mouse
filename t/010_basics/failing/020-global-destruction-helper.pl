#!/usr/bin/perl

use strict;
use warnings;


{
    package Foo;
    use Mouse;

    sub DEMOLISH {
        my $self = shift;
        my ($igd) = @_;

        print $igd;
    }
}

{
    package Bar;
    use Mouse;

    sub DEMOLISH {
        my $self = shift;
        my ($igd) = @_;

        print $igd;
    }

    __PACKAGE__->meta->make_immutable;
}

our $foo = Foo->new;
our $bar = Bar->new;
