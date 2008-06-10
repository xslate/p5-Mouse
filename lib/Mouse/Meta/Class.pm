#!/usr/bin/env perl
package Mouse::Meta::Class;
use strict;
use warnings;

use MRO::Compat;

do {
    my %METACLASS_CACHE;
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
    my %args = @_;

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

sub add_attribute {
    my $self = shift;
    my $attr = shift;

    $self->{'attributes'}{$attr->name} = $attr;
}

sub get_attribute_map { $_[0]->{attributes} }
sub get_attribute     { $_[0]->{attributes}->{$_[1]} }

sub linearized_isa { @{ mro::get_linear_isa($_[0]->name) } }

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

=head2 get_attribute_map -> { name => Mouse::Meta::Attribute }

Returns a mapping of attribute names to their corresponding
L<Mouse::Meta::Attribute> objects.

=head2 get_attribute Name -> Mouse::Meta::Attribute | undef

Returns the L<Mouse::Meta::Attribute> with the given name.

=head2 linearized_isa -> [ClassNames]

Returns the list of classes in method dispatch order, with duplicates removed.

=cut

