#!/usr/bin/env perl
package Mouse::Attribute;
use strict;
use warnings;

use Carp 'confess';

sub new {
    my $class = shift;
    my %args  = @_;

    $args{init_arg} ||= $args{name};
    $args{is} ||= '';

    bless \%args, $class;
}

sub name      { $_[0]->{name} }
sub class     { $_[0]->{class} }
sub default   { $_[0]->{default} }
sub predicate { $_[0]->{predicate} }
sub clearer   { $_[0]->{clearer} }
sub handles   { $_[0]->{handles} }
sub weak_ref  { $_[0]->{weak_ref} }
sub init_arg  { $_[0]->{init_arg} }

sub generate_accessor {
    my $attribute = shift;

    my $key     = $attribute->{init_arg};
    my $default = $attribute->{default};
    my $trigger = $attribute->{trigger};

    my $accessor = 'sub {
        my $self = shift;';

    if ($attribute->{is} eq 'rw') {
        $accessor .= 'if (@_) {
            $self->{$key} = $_[0];';

        if ($attribute->{weak_ref}) {
            $accessor .= 'Scalar::Util::weaken($self->{$key});';
        }

        if ($trigger) {
            $accessor .= '$trigger->($self, $_[0], $attribute);';
        }

        $accessor .= '}';
    }
    else {
    }

    if ($attribute->{lazy}) {
        $accessor .= '$self->{$key} = ';
        $accessor .= ref($attribute->{default}) eq 'CODE'
                   ? '$default->($self)'
                   : '$default';
        $accessor .= ' if !exists($self->{$key});';
    }

    $accessor .= 'return $self->{$key}
    }';

    return eval $accessor;
}

sub generate_predicate {
    my $attribute = shift;
    my $key = $attribute->{init_arg};

    my $predicate = 'sub { exists($_[0]->{$key}) }';

    return eval $predicate;
}

sub generate_clearer {
    my $attribute = shift;
    my $key = $attribute->{init_arg};

    my $predicate = 'sub { delete($_[0]->{$key}) }';

    return eval $predicate;
}

sub generate_handles {
    my $attribute = shift;
    my $reader = $attribute->{name};

    my %method_map;

    for my $local_method (keys %{ $attribute->{handles} }) {
        my $remote_method = $attribute->{handles}{$local_method};

        my $method = 'sub {
            my $self = shift;
            $self->$reader->$remote_method(@_)
        }';

        $method_map{$local_method} = eval $method;
    }

    return \%method_map;
}

sub create {
    my ($self, $class, $name, %args) = @_;

    confess "You must specify a default for lazy attribute '$name'"
        if $args{lazy} && !exists($args{default});

    confess "Trigger is not allowed on read-only attribute '$name'"
        if $args{trigger} && $args{is} ne 'rw';

    confess "References are not allowed as default values, you must wrap the default of '$name' in a CODE reference (ex: sub { [] } and not [])"
        if ref($args{default})
        && ref($args{default}) ne 'CODE';

    $args{handles} = { map { $_ => $_ } @{ $args{handles} } }
        if $args{handles}
        && ref($args{handles}) eq 'ARRAY';

    confess "You must pass a HASH or ARRAY to handles"
        if exists($args{handles})
        && ref($args{handles}) ne 'HASH';

    my $attribute = $self->new(%args, name => $name, class => $class);
    my $meta = $class->meta;

    $meta->add_attribute($attribute);

    # install an accessor
    if ($attribute->{is} eq 'rw' || $attribute->{is} eq 'ro') {
        my $accessor = $attribute->generate_accessor;
        no strict 'refs';
        *{ $class . '::' . $name } = $accessor;
    }

    for my $method (qw/predicate clearer/) {
        if (exists $attribute->{$method}) {
            my $generator = "generate_$method";
            my $coderef = $attribute->$generator;
            no strict 'refs';
            *{ $class . '::' . $attribute->{$method} } = $coderef;
        }
    }

    if ($attribute->{handles}) {
        my $method_map = $attribute->generate_handles;
        for my $method_name (keys %$method_map) {
            no strict 'refs';
            *{ $class . '::' . $method_name } = $method_map->{$method_name};
        }
    }

    return $attribute;
}

1;

__END__

=head1 NAME

Mouse::Attribute - attribute metaclass

=head1 METHODS

=head2 new %args -> Mouse::Attribute

Instantiates a new Mouse::Attribute. Does nothing else.

=head2 create OwnerClass, AttributeName, %args -> Mouse::Attribute

Creates a new attribute in OwnerClass. Accessors and helper methods are
installed. Some error checking is done.

=head2 name -> AttributeName

=head2 class -> OwnerClass

=head2 default -> Value

=head2 predicate -> MethodName

=head2 clearer -> MethodName

=head2 handles -> { LocalName => RemoteName }

=head2 weak_ref -> Bool

=head2 init_arg -> Str

Informational methods.

=head2 generate_accessor -> CODE

Creates a new code reference for the attribute's accessor.

=head2 generate_predicate -> CODE

Creates a new code reference for the attribute's predicate.

=head2 generate_clearer -> CODE

Creates a new code reference for the attribute's clearer.

=head2 generate_handles -> { MethodName => CODE }

Creates a new code reference for each of the attribute's handles methods.

=cut

