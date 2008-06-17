#!/usr/bin/env perl
package Mouse::Meta::Role;
use strict;
use warnings;

do {
    my %METACLASS_CACHE;

    # because Mouse doesn't introspect existing classes, we're forced to
    # only pay attention to other Mouse classes
    sub _metaclass_cache {
        my $class = shift;
        my $name  = shift;
        return $METACLASS_CACHE{$name};
    }

    sub initialize {
        my $class = shift;
        my $name  = shift;
        $METACLASS_CACHE{$name} = $class->new(name => $name)
            if !exists($METACLASS_CACHE{$name});
        return $METACLASS_CACHE{$name};
    }
};

sub new {
    my $class = shift;
    my %args  = @_;

    bless \%args, $class;
}

sub name { $_[0]->{name} }

sub has_attribute { }

sub add_attribute {
    $_[0]->{attributes}->{$_[1]} = $_[2];
}

1;

