package Mouse::Object;
use strict;
use warnings;

sub new {
    my $class = shift;

    $class->throw_error('Cannot call new() on an instance') if ref $class;

    my $args = $class->BUILDARGS(@_);

    my $instance = Mouse::Meta::Class->initialize($class)->new_object($args);
    $instance->BUILDALL($args);
    return $instance;
}

sub BUILDARGS {
    my $class = shift;

    if (scalar @_ == 1) {
        (ref($_[0]) eq 'HASH')
            || $class->meta->throw_error("Single parameters to new() must be a HASH ref");
        return {%{$_[0]}};
    }
    else {
        return {@_};
    }
}

sub DESTROY { shift->DEMOLISHALL }

sub BUILDALL {
    my $self = shift;

    # short circuit
    return unless $self->can('BUILD');

    for my $class (reverse $self->meta->linearized_isa) {
        no strict 'refs';
        no warnings 'once';
        my $code = *{ $class . '::BUILD' }{CODE}
            or next;
        $code->($self, @_);
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
        my $demolish = do{ no strict 'refs'; *{"${class}::DEMOLISH"}{CODE} };
        $self->$demolish()
            if defined $demolish;
    }
    return;
}

sub dump { 
    my($self, $maxdepth) = @_;

    require 'Data/Dumper.pm'; # we don't want to create its namespace
    my $dd = Data::Dumper->new([$self]);
    $dd->Maxdepth($maxdepth || 1);
    return $dd->Dump();
}


sub does {
    my ($self, $role_name) = @_;
    (defined $role_name)
        || $self->meta->throw_error("You must supply a role name to does()");

    return $self->meta->does_role($role_name);
};

1;

__END__

=head1 NAME

Mouse::Object - we don't need to steenkin' constructor

=head1 METHODS

=head2 new arguments -> object

Instantiates a new Mouse::Object. This is obviously intended for subclasses.

=head2 BUILDALL \%args

Calls L</BUILD> on each class in the class hierarchy. This is called at the
end of L</new>.

=head2 BUILD \%args

You may put any business logic initialization in BUILD methods. You don't
need to redispatch or return any specific value.

=head2 BUILDARGS

Lets you override the arguments that C<new> takes. Return a hashref of
parameters.

=head2 DEMOLISHALL

Calls L</DEMOLISH> on each class in the class hierarchy. This is called at
L</DESTROY> time.

=head2 DEMOLISH

You may put any business logic deinitialization in DEMOLISH methods. You don't
need to redispatch or return any specific value.


=head2 does $role_name

This will check if the invocant's class "does" a given C<$role_name>.
This is similar to "isa" for object, but it checks the roles instead.


=head2 B<dump ($maxdepth)>

From the Moose POD:

    C'mon, how many times have you written the following code while debugging:

     use Data::Dumper; 
     warn Dumper $obj;

    It can get seriously annoying, so why not just use this.

The implementation was lifted directly from Moose::Object.

=cut


