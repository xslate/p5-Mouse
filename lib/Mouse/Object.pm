package Mouse::Object;
use Mouse::Util qw(does dump meta); # enables strict and warnings

sub new;

sub BUILDALL {
    my $self = shift;

    # short circuit
    return unless $self->can('BUILD');

    for my $class (reverse $self->meta->linearized_isa) {
        my $build = Mouse::Util::get_code_ref($class, 'BUILD')
            || next;

        $self->$build(@_);
    }
    return;
}

sub DEMOLISHALL {
    my $self = shift;

    # short circuit
    return unless $self->can('DEMOLISH');

    # We cannot count on being able to retrieve a previously made
    # metaclass, _or_ being able to make a new one during global
    # destruction. However, we should still be able to use mro at
    # that time (at least tests suggest so ;)

    foreach my $class (@{ Mouse::Util::get_linear_isa(ref $self) }) {
        my $demolish = Mouse::Util::get_code_ref($class, 'DEMOLISH')
            || next;

        $self->$demolish();
    }
    return;
}

1;
__END__

=head1 NAME

Mouse::Object - The base object for Mouse classes

=head1 VERSION

This document describes Mouse version 0.43

=head1 METHODS

=head2 C<< new (Arguments) -> Object >>

Instantiates a new C<Mouse::Object>. This is obviously intended for subclasses.

=head2 C<< BUILDARGS (Arguments) -> HashRef >>

Lets you override the arguments that C<new> takes. Return a hashref of
parameters.

=head2 C<< BUILDALL (\%args) >>

Calls C<BUILD> on each class in the class hierarchy. This is called at the
end of C<new>.

=head2 C<< BUILD (\%args) >>

You may put any business logic initialization in BUILD methods. You don't
need to redispatch or return any specific value.

=head2 C<< DEMOLISHALL >>

Calls C<DEMOLISH> on each class in the class hierarchy. This is called at
C<DESTROY> time.

=head2 C<< DEMOLISH >>

You may put any business logic deinitialization in DEMOLISH methods. You don't
need to redispatch or return any specific value.


=head2 C<< does ($role_name) -> Bool >>

This will check if the invocant's class B<does> a given C<$role_name>.
This is similar to "isa" for object, but it checks the roles instead.

=head2 C<< dump ($maxdepth) -> Str >>

From the Moose POD:

    C'mon, how many times have you written the following code while debugging:

     use Data::Dumper; 
     warn Dumper $obj;

    It can get seriously annoying, so why not just use this.

The implementation was lifted directly from Moose::Object.

=head1 SEE ALSO

L<Moose::Object>

=cut

