package Mouse::Meta::TypeConstraint;
use Mouse::Util qw(:meta); # enables strict and warnings
use Scalar::Util ();

sub new {
    my $class = shift;
    my %args  = @_ == 1 ? %{$_[0]} : @_;

    $args{name} = '__ANON__' if !defined $args{name};

    if($args{parent}) {
        %args = (%{$args{parent}}, %args);
        # a child type must not inherit 'compiled_type_constraint'
        # and 'hand_optimized_type_constraint' from the parent
        delete $args{compiled_type_constraint};
        delete $args{hand_optimized_type_constraint};
    }

    my $check;

    if($check = delete $args{optimized}) {
        $args{hand_optimized_type_constraint} = $check;
        $args{compiled_type_constraint}       = $check;
    }
    elsif(my $param = $args{type_parameter}) {
        my $generator = $args{constraint_generator}
            || $class->throw_error("The $args{name} constraint cannot be used,"
                . " because $param doesn't subtype from a parameterizable type");
        # it must be 'constraint'
        $check = $args{constraint} = $generator->($param);
    }
    else {
        $check = $args{constraint};
    }

    if(defined($check) && ref($check) ne 'CODE'){
        $class->throw_error(
            "Constraint for $args{name} is not a CODE reference");
    }

    my $self = bless \%args, $class;
    $self->compile_type_constraint()
        if !$args{hand_optimized_type_constraint};

    if($args{type_constraints}) {
        $self->_compile_union_type_coercion();
    }
    return $self;
}

sub create_child_type {
    my $self = shift;
    return ref($self)->new(@_, parent => $self);
}

sub name;
sub parent;
sub message;
sub has_coercion;

sub check;

sub type_parameter;
sub __is_parameterized;

sub _compiled_type_constraint;
sub _compiled_type_coercion;

sub compile_type_constraint;


sub _add_type_coercions { # ($self, @pairs)
    my $self = shift;

    my $coercions = ($self->{coercion_map} ||= []);
    my %has       = map{ $_->[0] => undef } @{$coercions};

    for(my $i = 0; $i < @_; $i++){
        my $from   = $_[  $i];
        my $action = $_[++$i];

        if(exists $has{$from}){
            $self->throw_error("A coercion action already exists for '$from'");
        }

        my $type = Mouse::Util::TypeConstraints::find_or_parse_type_constraint($from)
            or $self->throw_error(
                "Could not find the type constraint ($from) to coerce from");

        push @{$coercions}, [ $type => $action ];
    }

    # compile
    if(exists $self->{type_constraints}){ # union type
        $self->throw_error(
            "Cannot add additional type coercions to Union types");
    }
    else{
        $self->_compile_type_coercion();
    }
    return;
}

sub _compile_type_coercion {
    my($self) = @_;

    my @coercions = @{$self->{coercion_map}};

    $self->{_compiled_type_coercion} = sub {
       my($thing) = @_;
       foreach my $pair (@coercions) {
            #my ($constraint, $converter) = @$pair;
            if ($pair->[0]->check($thing)) {
              local $_ = $thing;
              return $pair->[1]->($thing);
            }
       }
       return $thing;
    };
    return;
}

sub _compile_union_type_coercion {
    my($self) = @_;

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
    return;
}

sub coerce {
    my $self = shift;

    my $coercion = $self->_compiled_type_coercion;
    if(!$coercion){
        $self->throw_error("Cannot coerce without a type coercion");
    }

    return $_[0] if $self->check(@_);

    return  $coercion->(@_);
}

sub get_message {
    my ($self, $value) = @_;
    if ( my $msg = $self->message ) {
        local $_ = $value;
        return $msg->($value);
    }
    else {
        if(not defined $value) {
            $value = 'undef';
        }
        elsif( ref($value) && defined(&overload::StrVal) ) {
            $value = overload::StrVal($value);
        }
        return "Validation failed for '$self' with value $value";
    }
}

sub is_a_type_of{
    my($self, $other) = @_;

    # ->is_a_type_of('__ANON__') is always false
    return 0 if !ref($other) && $other eq '__ANON__';

    (my $other_name = $other) =~ s/\s+//g;

    return 1 if $self->name eq $other_name;

    if(exists $self->{type_constraints}){ # union
        foreach my $type(@{$self->{type_constraints}}) {
            return 1 if $type->name eq $other_name;
        }
    }

    for(my $p = $self->parent; defined $p; $p = $p->parent) {
        return 1 if $p->name eq $other_name;
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
    return Mouse::Meta::TypeConstraint->new(
        name           => $name,
        parent         => $self,
        type_parameter => $param,
    );
}

sub assert_valid {
    my ($self, $value) = @_;

    if(!$self->check($value)){
        $self->throw_error($self->get_message($value));
    }
    return 1;
}

sub _as_string { $_[0]->name                  } # overload ""
sub _identity  { Scalar::Util::refaddr($_[0]) } # overload 0+

sub _unite { # overload infix:<|>
    my($lhs, $rhs) = @_;
    require Mouse::Util::TypeConstraints;
    return Mouse::Util::TypeConstraints::find_or_parse_type_constraint(
       " $lhs | $rhs",
    );
}

1;
__END__

=head1 NAME

Mouse::Meta::TypeConstraint - The Mouse Type Constraint metaclass

=head1 VERSION

This document describes Mouse version 0.72

=head1 DESCRIPTION

This class represents a type constraint, including built-in
type constraints, union type constraints, parameterizable/
parameterized type constraints, as well as custom type
constraints

=head1 METHODS

=over

=item C<< Mouse::Meta::TypeConstraint->new(%options) >>

=item C<< $constraint->name >>

=item C<< $constraint->parent >>

=item C<< $constraint->constraint >>

=item C<< $constraint->has_coercion >>

=item C<< $constraint->message >>

=item C<< $constraint->is_a_subtype_of($name or $object) >>

=item C<< $constraint->coerce($value) >>

=item C<< $constraint->check($value) >>

=item C<< $constraint->assert_valid($value) >>

=item C<< $constraint->get_message($value) >>

=item C<< $constraint->create_child_type(%options) >>

=back

=head1 SEE ALSO

L<Moose::Meta::TypeConstraint>

=cut

