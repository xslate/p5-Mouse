package Mouse::Meta::TypeConstraint;
use strict;
use warnings;
use overload '""'     => sub { shift->{name} },   # stringify to tc name
             fallback => 1;

sub new {
    my $class = shift;
    my %args = @_;
    my $name = $args{name} || '__ANON__';

    my $check = $args{_compiled_type_constraint} or Carp::croak("missing _compiled_type_constraint");
    if (ref $check eq 'Mouse::Meta::TypeConstraint') {
        $check = $check->{_compiled_type_constraint};
    }

    bless +{
        name                      => $name,
        _compiled_type_constraint => $check,
        message                   => $args{message}
    }, $class;
}

sub name { shift->{name} }

sub check {
    my $self = shift;
    $self->{_compiled_type_constraint}->(@_);
}

sub message {
    return $_[0]->{message};
}

sub get_message {
    my ($self, $value) = @_;
    if ( my $msg = $self->message ) {
        local $_ = $value;
        return $msg->($value);
    }
    else {
        $value = ( defined $value ? overload::StrVal($value) : 'undef' );
        return
            "Validation failed for '"
          . $self->name
          . "' failed with value $value";
    }
}

1;
__END__

=head1 NAME

Mouse::Meta::TypeConstraint - The Mouse Type Constraint Metaclass

=head1 DESCRIPTION

For the most part, the only time you will ever encounter an
instance of this class is if you are doing some serious deep
introspection. This API should not be considered final, but
it is B<highly unlikely> that this will matter to a regular
Mouse user.

Don't use this.

=head1 METHODS

=over 4

=item B<new>

=item B<name>

=back

=cut

