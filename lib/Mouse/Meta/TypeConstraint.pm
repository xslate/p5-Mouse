package Mouse::Meta::TypeConstraint;
use Mouse::Util qw(:meta); # enables strict and warnings

use overload
    '""'     => sub { shift->{name} },   # stringify to tc name
    fallback => 1;

use Carp qw(confess);
use Scalar::Util qw(blessed reftype);

my $null_check = sub { 1 };

sub new {
    my($class, %args) = @_;

    $args{name} = '__ANON__' if !defined $args{name};

    my $check = delete $args{optimized};

    if($args{_compiled_type_constraint}){
        Carp::cluck("'_compiled_type_constraint' has been deprecated, use 'optimized' instead")
            if _MOUSE_VERBOSE;

        $check = $args{_compiled_type_constraint};
    }

    if($check){
        $args{hand_optimized_type_constraint} = $check;
        $args{compiled_type_constraint}       = $check;
    }

    $check = $args{constraint};

    if(blessed($check)){
        Carp::cluck("Constraint for $args{name} must be a CODE reference");
        $check = $check->{compiled_type_constraint};
    }

    if(defined($check) && ref($check) ne 'CODE'){
        confess("Constraint for $args{name} is not a CODE reference");
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

sub name    { $_[0]->{name}    }
sub parent  { $_[0]->{parent}  }
sub message { $_[0]->{message} }

sub _compiled_type_constraint{ $_[0]->{compiled_type_constraint} }

sub has_coercion{ exists $_[0]->{_compiled_type_coercion} }

sub compile_type_constraint{
    my($self) = @_;

    # add parents first
    my @checks;
    for(my $parent = $self->parent; defined $parent; $parent = $parent->parent){
         if($parent->{hand_optimized_type_constraint}){
            unshift @checks, $parent->{hand_optimized_type_constraint};
            last; # a hand optimized constraint must include all the parents
        }
        elsif($parent->{constraint}){
            unshift @checks, $parent->{constraint};
        }
    }

    # then add child
    if($self->{constraint}){
        push @checks, $self->{constraint};
    }

    if($self->{type_constraints}){ # Union
        my @types = map{ $_->_compiled_type_constraint } @{ $self->{type_constraints} };
        push @checks, sub{
            foreach my $c(@types){
                return 1 if $c->($_[0]);
            }
            return 0;
        };
    }

    if(@checks == 0){
        $self->{compiled_type_constraint} = $null_check;
    }
    elsif(@checks == 1){
        my $c = $checks[0];
        $self->{compiled_type_constraint} = sub{
            my(@args) = @_;
            local $_ = $args[0];
            return $c->(@args);
        };
    }
    else{
        $self->{compiled_type_constraint} =  sub{
            my(@args) = @_;
            local $_ = $args[0];
            foreach my $c(@checks){
                return undef if !$c->(@args);
            }
            return 1;
        };
    }
    return;
}

sub _add_type_coercions{
    my $self = shift;

    my $coercions = ($self->{_coercion_map} ||= []);
    my %has       = map{ $_->[0] => undef } @{$coercions};

    for(my $i = 0; $i < @_; $i++){
        my $from   = $_[  $i];
        my $action = $_[++$i];

        if(exists $has{$from}){
            confess("A coercion action already exists for '$from'");
        }

        my $type = Mouse::Util::TypeConstraints::find_or_parse_type_constraint($from)
            or confess("Could not find the type constraint ($from) to coerce from");

        push @{$coercions}, [ $type => $action ];
    }

    # compile
    if(exists $self->{type_constraints}){ # union type
        confess("Cannot add additional type coercions to Union types");
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
    if(!$self->{_compiled_type_coercion}){
        confess("Cannot coerce without a type coercion ($self)");
    }

    return $_[0] if $self->_compiled_type_constraint->(@_);

    return $self->{_compiled_type_coercion}->(@_);
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


1;
__END__

=head1 NAME

Mouse::Meta::TypeConstraint - The Mouse Type Constraint metaclass

=head1 VERSION

This document describes Mouse version 0.40

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

