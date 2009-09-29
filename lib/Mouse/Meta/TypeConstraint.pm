package Mouse::Meta::TypeConstraint;
use strict;
use warnings;

use overload
    '""'     => sub { shift->{name} },   # stringify to tc name
    fallback => 1;

use Carp qw(confess);
use Scalar::Util qw(blessed reftype);

use Mouse::Util qw(:meta);

my $null_check = sub { 1 };

sub new {
    my($class, %args) = @_;

    $args{name} = '__ANON__' if !defined $args{name};

    my $check = $args{_compiled_type_constraint} || $args{constraint};

    if(blessed($check)){
        Carp::cluck("'constraint' must be a CODE reference");
        $check = $check->{_compiled_type_constraint};
    }

    if(defined($check) && ref($check) ne 'CODE'){
        confess("Type constraint for $args{name} is not a CODE reference");
    }

    my $self = bless \%args, $class;
    $self->{_compiled_type_constraint} ||= $self->_compile();

    return $self;
}

sub create_child_type{
    my $self = shift;
    return ref($self)->new(@_, parent => $self);
}

sub name    { $_[0]->{name}    }
sub parent  { $_[0]->{parent}  }
sub message { $_[0]->{message} }

sub check {
    my $self = shift;
    $self->{_compiled_type_constraint}->(@_);
}

sub validate {
    my ($self, $value) = @_;
    if ($self->{_compiled_type_constraint}->($value)) {
        return undef;
    }
    else {
        $self->get_message($value);
    }
}

sub assert_valid {
    my ($self, $value) = @_;

    my $error = $self->validate($value);
    return 1 if ! defined $error;

    confess($error);
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

sub is_a_type_of{
    my($self, $other) = @_;

    # ->is_a_type_of('__ANON__') is always false
    return 0 if !blessed($other) && $other eq '__ANON__';

    (my $other_name = $other) =~ s/\s+//g;

    return 1 if $self->name eq $other_name;

    if(exists $self->{type_constraints}){ # union
        foreach my $type(@{$self->{type_constraints}}){
            return 1 if $type->name eq $other_name;
        }
    }

    for(my $parent = $self->parent; defined $parent; $parent = $parent->parent){
        return 1 if $parent->name eq $other_name;
    }

    return 0;
}

sub _compile{
    my($self) = @_;

    # add parents first
    my @checks;
    for(my $parent = $self->parent; defined $parent; $parent = $parent->parent){
        if($parent->{constraint}){
            push @checks, $parent->{constraint};
         }
         elsif($parent->{_compiled_type_constraint} && $parent->{_compiled_type_constraint} != $null_check){
            # hand-optimized constraint
            push @checks, $parent->{_compiled_type_constraint};
            last;
        }
    }
    # then add child
    if($self->{constraint}){
        push @checks, $self->{constraint};
    }

    if(@checks == 0){
        return $null_check;
    }
    elsif(@checks == 1){
        my $c = $checks[0];
        return sub{
            my(@args) = @_;
            local $_ = $args[0];
            return $c->(@args);
        };
    }
    else{
        return sub{
            my(@args) = @_;
            local $_ = $args[0];
            foreach my $c(@checks){
                return undef if !$c->(@args);
            }
            return 1;
        };
    }
}

1;
__END__

=head1 NAME

Mouse::Meta::TypeConstraint - The Mouse Type Constraint metaclass

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

=head1 SEE ALSO

L<Moose::Meta::TypeConstraint>

=cut

