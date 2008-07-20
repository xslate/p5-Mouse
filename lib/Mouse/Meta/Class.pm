#!/usr/bin/env perl
package Mouse::Meta::Class;
use strict;
use warnings;

use Scalar::Util 'blessed';
use Carp 'confess';

use MRO::Compat;

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

    $args{attributes} = {};
    $args{superclasses} = do {
        no strict 'refs';
        \@{ $args{name} . '::ISA' };
    };

    bless \%args, $class;
}

sub name { $_[0]->{name} }

sub superclasses {
    my $self = shift;

    if (@_) {
        Mouse::load_class($_) for @_;
        @{ $self->{superclasses} } = @_;
    }

    @{ $self->{superclasses} };
}

sub add_method {
    my $self = shift;
    my $name = shift;
    my $code = shift;

    my $pkg = $self->name;

    no strict 'refs';
    *{ $pkg . '::' . $name } = $code;
}

sub add_attribute {
    my $self = shift;
    my $attr = shift;

    $self->{'attributes'}{$attr->name} = $attr;
}

sub compute_all_applicable_attributes {
    my $self = shift;
    my (@attr, %seen);

    for my $class ($self->linearized_isa) {
        my $meta = $self->_metaclass_cache($class)
            or next;

        for my $name (keys %{ $meta->get_attribute_map }) {
            next if $seen{$name}++;
            push @attr, $meta->get_attribute($name);
        }
    }

    return @attr;
}

sub get_attribute_map { $_[0]->{attributes} }
sub has_attribute     { exists $_[0]->{attributes}->{$_[1]} }
sub get_attribute     { $_[0]->{attributes}->{$_[1]} }

sub linearized_isa { @{ mro::get_linear_isa($_[0]->name) } }

sub clone_object {
    my $class    = shift;
    my $instance = shift;

    (blessed($instance) && $instance->isa($class->name))
        || confess "You must pass an instance of the metaclass (" . $class->name . "), not ($instance)";

    $class->clone_instance($instance, @_);
}

sub clone_instance {
    my ($class, $instance, %params) = @_;

    (blessed($instance))
        || confess "You can only clone instances, ($instance) is not a blessed instance";

    my $clone = bless { %$instance }, ref $instance;

    foreach my $attr ($class->compute_all_applicable_attributes()) {
        if ( defined( my $init_arg = $attr->init_arg ) ) {
            if (exists $params{$init_arg}) {
                $clone->{ $attr->name } = $params{$init_arg};
            }
        }
    }

    return $clone;

}

sub make_immutable {}

1;

__END__

=head1 NAME

Mouse::Meta::Class - hook into the Mouse MOP

=head1 METHODS

=head2 initialize ClassName -> Mouse::Meta::Class

Finds or creates a Mouse::Meta::Class instance for the given ClassName. Only
one instance should exist for a given class.

=head2 new %args -> Mouse::Meta::Class

Creates a new Mouse::Meta::Class. Don't call this directly.

=head2 name -> ClassName

Returns the name of the owner class.

=head2 superclasses -> [ClassName]

Gets (or sets) the list of superclasses of the owner class.

=head2 add_attribute Mouse::Meta::Attribute

Begins keeping track of the existing L<Mouse::Meta::Attribute> for the owner
class.

=head2 compute_all_applicable_attributes -> (Mouse::Meta::Attribute)

Returns the list of all L<Mouse::Meta::Attribute> instances associated with
this class and its superclasses.

=head2 get_attribute_map -> { name => Mouse::Meta::Attribute }

Returns a mapping of attribute names to their corresponding
L<Mouse::Meta::Attribute> objects.

=head2 has_attribute Name -> Boool

Returns whether we have a L<Mouse::Meta::Attribute> with the given name.

=head2 get_attribute Name -> Mouse::Meta::Attribute | undef

Returns the L<Mouse::Meta::Attribute> with the given name.

=head2 linearized_isa -> [ClassNames]

Returns the list of classes in method dispatch order, with duplicates removed.

=head2 clone_object Instance -> Instance

Clones the given C<Instance> which must be an instance governed by this
metaclass.

=head2 clone_instance Instance, Parameters -> Instance

Clones the given C<Instance> and sets any additional parameters.

=cut

