package Mouse::Meta::TypeConstraint;
use Mouse::Util qw(:meta); # enables strict and warnings

use overload
    'bool'   => sub { 1 },             # always true

    '""'     => sub { $_[0]->name },   # stringify to tc name

    '|'      => sub {                  # or-combination
        require Mouse::Util::TypeConstraints;
        return Mouse::Util::TypeConstraints::find_or_parse_type_constraint(
            "$_[0] | $_[1]",
        );
    },

    fallback => 1;

use Carp         ();

sub new {
    my($class, %args) = @_;

    $args{name} = '__ANON__' if !defined $args{name};

    my $check = delete $args{optimized};

    if($args{_compiled_type_constraint}){
        Carp::cluck("'_compiled_type_constraint' has been deprecated, use 'optimized' instead")
            if Mouse::Util::_MOUSE_VERBOSE;

        $check = $args{_compiled_type_constraint};
    }

    if($check){
        $args{hand_optimized_type_constraint} = $check;
        $args{compiled_type_constraint}       = $check;
    }

    $check = $args{constraint};

    if(defined($check) && ref($check) ne 'CODE'){
        Carp::confess("Constraint for $args{name} is not a CODE reference");
    }

    $args{package_defined_in} ||= caller;

    my $self = bless \%args, $class;
    $self->compile_type_constraint() if !$self->{hand_optimized_type_constraint};

    if($self->{type_constraints}){ # Union
        my @coercions;
        foreach my $type(@{$self->{type_constraints}}){
            if($type->has_coercion){
                push @coercions, $type;
            }
        }
        if(@coercions){
            $self->{_compiled_type_coercion} = sub {
                my($thing) = @_;
                foreach my $type(@coercions){
                    my $value = $type->coerce($thing);
                    return $value if $self->check($value);
                }
                return $thing;
            };
        }
    }

    return $self;
}

sub create_child_type{
    my $self = shift;
    # XXX: FIXME
    return ref($self)->new(
        # a child inherits its parent's attributes
        %{$self},

        # but does not inherit 'compiled_type_constraint' and 'hand_optimized_type_constraint'
        compiled_type_constraint       => undef,
        hand_optimized_type_constraint => undef,

        # and is given child-specific args, of course.
        @_,

        # and its parent
        parent => $self,
   );
}

sub _add_type_coercions{
    my $self = shift;

    my $coercions = ($self->{_coercion_map} ||= []);
    my %has       = map{ $_->[0] => undef } @{$coercions};

    for(my $i = 0; $i < @_; $i++){
        my $from   = $_[  $i];
        my $action = $_[++$i];

        if(exists $has{$from}){
            Carp::confess("A coercion action already exists for '$from'");
        }

        my $type = Mouse::Util::TypeConstraints::find_or_parse_type_constraint($from)
            or Carp::confess("Could not find the type constraint ($from) to coerce from");

        push @{$coercions}, [ $type => $action ];
    }

    # compile
    if(exists $self->{type_constraints}){ # union type
        Carp::confess("Cannot add additional type coercions to Union types");
    }
    else{
        $self->{_compiled_type_coercion} = sub {
           my($thing) = @_;
           foreach my $pair (@{$coercions}) {
                #my ($constraint, $converter) = @$pair;
                if ($pair->[0]->check($thing)) {
                  local $_ = $thing;
                  return $pair->[1]->($thing);
                }
           }
           return $thing;
        };
    }
    return;
}

sub check {
    my $self = shift;
    return $self->_compiled_type_constraint->(@_);
}

sub coerce {
    my $self = shift;

    return $_[0] if $self->_compiled_type_constraint->(@_);

    my $coercion = $self->_compiled_type_coercion;
    return $coercion ? $coercion->(@_) : $_[0];
}

sub get_message {
    my ($self, $value) = @_;
    if ( my $msg = $self->message ) {
        local $_ = $value;
        return $msg->($value);
    }
    else {
        $value = ( defined $value ? overload::StrVal($value) : 'undef' );
        return "Validation failed for '$self' failed with value $value";
    }
}

sub is_a_type_of{
    my($self, $other) = @_;

    # ->is_a_type_of('__ANON__') is always false
    return 0 if !ref($other) && $other eq '__ANON__';

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

# See also Moose::Meta::TypeConstraint::Parameterizable
sub parameterize{
    my($self, $param, $name) = @_;

    if(!ref $param){
        require Mouse::Util::TypeConstraints;
        $param = Mouse::Util::TypeConstraints::find_or_create_isa_type_constraint($param);
    }

    $name ||= sprintf '%s[%s]', $self->name, $param->name;

    my $generator = $self->{constraint_generator}
        || Carp::confess("The $name constraint cannot be used, because $param doesn't subtype from a parameterizable type");

    return Mouse::Meta::TypeConstraint->new(
        name        => $name,
        parent      => $self,
        parameter   => $param,
        constraint  => $generator->($param), # must be 'constraint', not 'optimized'

        type        => 'Parameterized',
    );
}

1;
__END__

=head1 NAME

Mouse::Meta::TypeConstraint - The Mouse Type Constraint metaclass

=head1 VERSION

This document describes Mouse version 0.42

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

