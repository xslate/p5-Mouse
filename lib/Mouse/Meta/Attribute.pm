package Mouse::Meta::Attribute;
use strict;
use warnings;

use Scalar::Util ();
use Mouse::Meta::TypeConstraint;
use Mouse::Meta::Method::Accessor;

sub new {
    my ($class, $name, %options) = @_;

    $options{name} = $name;

    $options{init_arg} = $name
        unless exists $options{init_arg};

    my $is = $options{is} ||= '';

    if($is eq 'rw'){
        $options{accessor} = $name if !exists $options{accessor};
    }
    elsif($is eq 'ro'){
        $options{reader}   = $name if !exists $options{reader};
    }

    bless \%options, $class;
}

# readers

sub name                 { $_[0]->{name}                   }
sub associated_class     { $_[0]->{associated_class}       }

sub accessor             { $_[0]->{accessor}               }
sub reader               { $_[0]->{reader}                 }
sub writer               { $_[0]->{writer}                 }
sub predicate            { $_[0]->{predicate}              }
sub clearer              { $_[0]->{clearer}                }
sub handles              { $_[0]->{handles}                }

sub _is_metadata         { $_[0]->{is}                     }
sub is_required          { $_[0]->{required}               }
sub default              { $_[0]->{default}                }
sub is_lazy              { $_[0]->{lazy}                   }
sub is_lazy_build        { $_[0]->{lazy_build}             }
sub is_weak_ref          { $_[0]->{weak_ref}               }
sub init_arg             { $_[0]->{init_arg}               }
sub type_constraint      { $_[0]->{type_constraint}        }
sub find_type_constraint {
    Carp::carp("This method was deprecated");
    $_[0]->type_constraint();
}
sub trigger              { $_[0]->{trigger}                }
sub builder              { $_[0]->{builder}                }
sub should_auto_deref    { $_[0]->{auto_deref}             }
sub should_coerce        { $_[0]->{should_coerce}          }

# predicates

sub has_accessor         { exists $_[0]->{accessor}        }
sub has_reader           { exists $_[0]->{reader}          }
sub has_writer           { exists $_[0]->{writer}          }
sub has_predicate        { exists $_[0]->{predicate}       }
sub has_clearer          { exists $_[0]->{clearer}         }
sub has_handles          { exists $_[0]->{handles}         }

sub has_default          { exists $_[0]->{default}         }
sub has_type_constraint  { exists $_[0]->{type_constraint} }
sub has_trigger          { exists $_[0]->{trigger}         }
sub has_builder          { exists $_[0]->{builder}         }

sub _create_args {
    $_[0]->{_create_args} = $_[1] if @_ > 1;
    $_[0]->{_create_args}
}

sub accessor_metaclass { 'Mouse::Meta::Method::Accessor' }

sub _inlined_name {
    my $self = shift;
    return sprintf '"%s"', quotemeta $self->name;
}


sub create {
    my ($self, $class, $name, %args) = @_;

    $args{name}             = $name;
    $args{associated_class} = $class;

    %args = $self->canonicalize_args($name, %args);
    $self->validate_args($name, \%args);

    $args{should_coerce} = delete $args{coerce}
        if exists $args{coerce};

    if (exists $args{isa}) {
        my $type_constraint = delete $args{isa};
        $args{type_constraint}= Mouse::Util::TypeConstraints::find_or_create_isa_type_constraint($type_constraint);
    }

    my $attribute = $self->new($name, %args);

    $attribute->_create_args(\%args);

    $class->add_attribute($attribute);

    my $associated_methods = 0;

    my $generator_class = $self->accessor_metaclass;
    foreach my $type(qw(accessor reader writer predicate clearer handles)){
        if(exists $attribute->{$type}){
            my $installer    = '_install_' . $type;
            $generator_class->$installer($attribute, $attribute->{$type}, $class);
            $associated_methods++;
        }
    }

    if($associated_methods == 0 && ($attribute->_is_metadata || '') ne 'bare'){
        Carp::cluck(qq{Attribute ($name) of class }.$class->name.qq{ has no associated methods (did you mean to provide an "is" argument?)});

    }

    return $attribute;
}

sub canonicalize_args {
    my $self = shift;
    my $name = shift;
    my %args = @_;

    if ($args{lazy_build}) {
        $args{lazy}      = 1;
        $args{required}  = 1;
        $args{builder}   = "_build_${name}"
            if !exists($args{builder});
        if ($name =~ /^_/) {
            $args{clearer}   = "_clear${name}" if !exists($args{clearer});
            $args{predicate} = "_has${name}" if !exists($args{predicate});
        }
        else {
            $args{clearer}   = "clear_${name}" if !exists($args{clearer});
            $args{predicate} = "has_${name}" if !exists($args{predicate});
        }
    }

    return %args;
}

sub validate_args {
    my $self = shift;
    my $name = shift;
    my $args = shift;

    $self->throw_error("You can not use lazy_build and default for the same attribute ($name)")
        if $args->{lazy_build} && exists $args->{default};

    $self->throw_error("You cannot have lazy attribute ($name) without specifying a default value for it")
        if $args->{lazy}
        && !exists($args->{default})
        && !exists($args->{builder});

    $self->throw_error("References are not allowed as default values, you must wrap the default of '$name' in a CODE reference (ex: sub { [] } and not [])")
        if ref($args->{default})
        && ref($args->{default}) ne 'CODE';

    $self->throw_error("You cannot auto-dereference without specifying a type constraint on attribute ($name)")
        if $args->{auto_deref} && !exists($args->{isa});

    $self->throw_error("You cannot auto-dereference anything other than a ArrayRef or HashRef on attribute ($name)")
        if $args->{auto_deref}
        && $args->{isa} !~ /^(?:ArrayRef|HashRef)(?:\[.*\])?$/;

    if ($args->{trigger}) {
        if (ref($args->{trigger}) eq 'HASH') {
            $self->throw_error("HASH-based form of trigger has been removed. Only the coderef form of triggers are now supported.");
        }

        $self->throw_error("Trigger must be a CODE ref on attribute ($name)")
            if ref($args->{trigger}) ne 'CODE';
    }

    return 1;
}

sub verify_against_type_constraint {
    my ($self, $value) = @_;
    my $tc = $self->type_constraint;
    return 1 unless $tc;

    local $_ = $value;
    return 1 if $tc->check($value);

    $self->verify_type_constraint_error($self->name, $value, $tc);
}

sub verify_type_constraint_error {
    my($self, $name, $value, $type) = @_;
    $self->throw_error("Attribute ($name) does not pass the type constraint because: " . $type->get_message($value));
}

sub coerce_constraint { ## my($self, $value) = @_;
    my $type = $_[0]->{type_constraint}
        or return $_[1];
    return Mouse::Util::TypeConstraints->typecast_constraints($_[0]->associated_class->name, $_[0]->type_constraint, $_[1]);
}

sub _canonicalize_handles {
    my $self    = shift;
    my $handles = shift;

    if (ref($handles) eq 'HASH') {
        return %$handles;
    }
    elsif (ref($handles) eq 'ARRAY') {
        return map { $_ => $_ } @$handles;
    }
    else {
        $self->throw_error("Unable to canonicalize the 'handles' option with $handles");
    }
}

sub clone_parent {
    my $self  = shift;
    my $class = shift;
    my $name  = shift;
    my %args  = ($self->get_parent_args($class, $name), @_);

    $self->create($class, $name, %args);
}

sub get_parent_args {
    my $self  = shift;
    my $class = shift;
    my $name  = shift;

    for my $super ($class->linearized_isa) {
        my $super_attr = $super->can("meta") && $super->meta->get_attribute($name)
            or next;
        return %{ $super_attr->_create_args };
    }

    $self->throw_error("Could not find an attribute by the name of '$name' to inherit from");
}

sub throw_error{
    my $self = shift;

    my $metaclass = (ref $self && $self->associated_class) || 'Mouse::Meta::Class';
    $metaclass->throw_error(@_, depth => 1);
}

1;

__END__

=head1 NAME

Mouse::Meta::Attribute - attribute metaclass

=head1 METHODS

=head2 new %args -> Mouse::Meta::Attribute

Instantiates a new Mouse::Meta::Attribute. Does nothing else.

=head2 create OwnerClass, AttributeName, %args -> Mouse::Meta::Attribute

Creates a new attribute in OwnerClass. Accessors and helper methods are
installed. Some error checking is done.

=head2 name -> AttributeName

=head2 associated_class -> OwnerClass

=head2 is_required -> Bool

=head2 default -> Item

=head2 has_default -> Bool

=head2 is_lazy -> Bool

=head2 predicate -> MethodName | Undef

=head2 has_predicate -> Bool

=head2 clearer -> MethodName | Undef

=head2 has_clearer -> Bool

=head2 handles -> { LocalName => RemoteName }

=head2 has_handles -> Bool

=head2 is_weak_ref -> Bool

=head2 init_arg -> Str

=head2 type_constraint -> Str

=head2 has_type_constraint -> Bool

=head2 trigger => CODE | Undef

=head2 has_trigger -> Bool

=head2 builder => MethodName | Undef

=head2 has_builder -> Bool

=head2 is_lazy_build => Bool

=head2 should_auto_deref -> Bool

Informational methods.

=head2 verify_against_type_constraint Item -> 1 | ERROR

Checks that the given value passes this attribute's type constraint. Returns 1
on success, otherwise C<confess>es.

=head2 canonicalize_args Name, %args -> %args

Canonicalizes some arguments to create. In particular, C<lazy_build> is
canonicalized into C<lazy>, C<builder>, etc.

=head2 validate_args Name, \%args -> 1 | ERROR

Checks that the arguments to create the attribute (ie those specified by
C<has>) are valid.

=head2 clone_parent OwnerClass, AttributeName, %args -> Mouse::Meta::Attribute

Creates a new attribute in OwnerClass, inheriting options from parent classes.
Accessors and helper methods are installed. Some error checking is done.

=head2 get_parent_args OwnerClass, AttributeName -> Hash

Returns the options that the parent class of C<OwnerClass> used for attribute
C<AttributeName>.

=cut

