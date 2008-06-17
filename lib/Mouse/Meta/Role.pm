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

    $args{attributes} ||= {};

    bless \%args, $class;
}

sub name { $_[0]->{name} }

sub add_attribute {
    my $self = shift;
    my $name = shift;
    $self->{attributes}->{$name} = [ @_ ];
}

sub has_attribute { exists $_[0]->{attributes}->{$_[1]}  }
sub get_attribute_list { keys %{ $_[0]->{attributes} } }
sub get_attribute { @{ $_->[0]->{attributes}->{$_[1]} || [] } }

sub apply {
    my $self  = shift;
    my $class = shift;
    my $pkg   = $class->name;

    for my $name ($self->get_attribute_list) {
        my @spec = $self->get_attribute($name);
        Mouse::Meta::Attribute->create($pkg, $name, @spec);
    }

}

1;

