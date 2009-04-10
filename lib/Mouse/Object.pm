package Mouse::Object;
use strict;
use warnings;

use Scalar::Util 'weaken';
use Carp 'confess';

sub new {
    my $class = shift;

    my $args = $class->BUILDARGS(@_);

    my $instance = bless {}, $class;

    for my $attribute ($class->meta->get_all_attributes) {
        my $from = $attribute->init_arg;
        my $key  = $attribute->name;

        if (defined($from) && exists($args->{$from})) {
            $args->{$from} = $attribute->coerce_constraint($args->{$from})
                if $attribute->should_coerce;
            $attribute->verify_against_type_constraint($args->{$from});

            $instance->{$key} = $args->{$from};

            weaken($instance->{$key})
                if ref($instance->{$key}) && $attribute->is_weak_ref;

            if ($attribute->has_trigger) {
                $attribute->trigger->($instance, $args->{$from});
            }
        }
        else {
            if ($attribute->has_default || $attribute->has_builder) {
                unless ($attribute->is_lazy) {
                    my $default = $attribute->default;
                    my $builder = $attribute->builder;
                    my $value = $attribute->has_builder
                              ? $instance->$builder
                              : ref($default) eq 'CODE'
                                  ? $default->($instance)
                                  : $default;

                    $value = $attribute->coerce_constraint($value)
                        if $attribute->should_coerce;
                    $attribute->verify_against_type_constraint($value);

                    $instance->{$key} = $value;

                    weaken($instance->{$key})
                        if ref($instance->{$key}) && $attribute->is_weak_ref;
                }
            }
            else {
                if ($attribute->is_required) {
                    confess "Attribute (".$attribute->name.") is required";
                }
            }
        }
    }

    $instance->BUILDALL($args);

    return $instance;
}

sub BUILDARGS {
    my $class = shift;

    if (scalar @_ == 1) {
        (ref($_[0]) eq 'HASH')
            || confess "Single parameters to new() must be a HASH ref";
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
}

sub DEMOLISHALL {
    my $self = shift;

    # short circuit
    return unless $self->can('DEMOLISH');

    no strict 'refs';

    for my $class ($self->meta->linearized_isa) {
        my $code = *{ $class . '::DEMOLISH' }{CODE}
            or next;
        $code->($self, @_);
    }
}

sub dump { 
    my $self = shift;
    require Data::Dumper;
    local $Data::Dumper::Maxdepth = shift if @_;
    Data::Dumper::Dumper $self;
}


sub does {
    my ($self, $role_name) = @_;
    (defined $role_name)
        || confess "You must supply a role name to does()";
    my $meta = $self->meta;
    foreach my $class ($meta->linearized_isa) {
        my $m = $meta->initialize($class);
        return 1 
            if $m->can('does_role') && $m->does_role($role_name);            
    }
    return 0;   
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


