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
    my $spec = shift;
    $self->{attributes}->{$name} = $spec;
}

sub has_attribute { exists $_[0]->{attributes}->{$_[1]}  }
sub get_attribute_list { keys %{ $_[0]->{attributes} } }
sub get_attribute { $_[0]->{attributes}->{$_[1]} }

sub apply {
    my $self  = shift;
    my $class = shift;

    for my $name ($self->get_attribute_list) {
        next if $class->has_attribute($name);
        my $spec = $self->get_attribute($name);
        Mouse::Meta::Attribute->create($class, $name, %$spec);
    }

    for my $modifier_type (qw/before after around/) {
        my $add_method = "add_${modifier_type}_method_modifier";
        my $modified = $self->{"${modifier_type}_method_modifiers"};

        for my $method_name (keys %$modified) {
            for my $code (@{ $modified->{$method_name} }) {
                $class->$add_method($method_name => $code);
            }
        }
    }
}

for my $modifier_type (qw/before after around/) {
    no strict 'refs';
    *{ __PACKAGE__ . '::' . "add_${modifier_type}_method_modifier" } = sub {
        my ($self, $method_name, $method) = @_;

        push @{ $self->{"${modifier_type}_method_modifiers"}->{$method_name} },
            $method;
    };

    *{ __PACKAGE__ . '::' . "get_${modifier_type}_method_modifiers" } = sub {
        my ($self, $method_name, $method) = @_;
        @{ $self->{"${modifier_type}_method_modifiers"}->{$method_name} || [] }
    };
}

1;

