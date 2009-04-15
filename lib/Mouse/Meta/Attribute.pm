package Mouse::Meta::Attribute;
use strict;
use warnings;
require overload;

use Carp 'confess';
use Scalar::Util ();
use Mouse::Meta::TypeConstraint;
use Mouse::Meta::Method::Accessor;

sub new {
    my ($class, $name, %options) = @_;

    $options{name} = $name;

    $options{init_arg} = $name
        unless exists $options{init_arg};

    $options{is} ||= '';

    bless \%options, $class;
}

sub name                 { $_[0]->{name}                   }
sub associated_class     { $_[0]->{associated_class}       }
sub _is_metadata         { $_[0]->{is}                     }
sub is_required          { $_[0]->{required}               }
sub default              { $_[0]->{default}                }
sub is_lazy              { $_[0]->{lazy}                   }
sub is_lazy_build        { $_[0]->{lazy_build}             }
sub predicate            { $_[0]->{predicate}              }
sub clearer              { $_[0]->{clearer}                }
sub handles              { $_[0]->{handles}                }
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

sub has_default          { exists $_[0]->{default}         }
sub has_predicate        { exists $_[0]->{predicate}       }
sub has_clearer          { exists $_[0]->{clearer}         }
sub has_handles          { exists $_[0]->{handles}         }
sub has_type_constraint  { exists $_[0]->{type_constraint} }
sub has_trigger          { exists $_[0]->{trigger}         }
sub has_builder          { exists $_[0]->{builder}         }

sub _create_args {
    $_[0]->{_create_args} = $_[1] if @_ > 1;
    $_[0]->{_create_args}
}

sub inlined_name {
    my $self = shift;
    my $name = $self->name;
    my $key   = "'" . $name . "'";
    return $key;
}

sub generate_predicate {
    my $attribute = shift;
    my $key = $attribute->inlined_name;

    my $predicate = 'sub { exists($_[0]->{'.$key.'}) }';

    my $sub = eval $predicate;
    confess $@ if $@;
    return $sub;
}

sub generate_clearer {
    my $attribute = shift;
    my $key = $attribute->inlined_name;

    my $clearer = 'sub { delete($_[0]->{'.$key.'}) }';

    my $sub = eval $clearer;
    confess $@ if $@;
    return $sub;
}

sub generate_handles {
    my $attribute = shift;
    my $reader = $attribute->name;
    my %handles = $attribute->_canonicalize_handles($attribute->handles);

    my %method_map;

    for my $local_method (keys %handles) {
        my $remote_method = $handles{$local_method};

        my $method = 'sub {
            my $self = shift;
            $self->'.$reader.'->'.$remote_method.'(@_)
        }';

        $method_map{$local_method} = eval $method;
        confess $@ if $@;
    }

    return \%method_map;
}

sub create {
    my ($self, $class, $name, %args) = @_;

    $args{name} = $name;
    $args{associated_class} = $class;

    %args = $self->canonicalize_args($name, %args);
    $self->validate_args($name, \%args);

    $args{should_coerce} = delete $args{coerce}
        if exists $args{coerce};

    if (exists $args{isa}) {
        confess "Got isa => $args{isa}, but Mouse does not yet support parameterized types for containers other than ArrayRef and HashRef (rt.cpan.org #39795)"
            if $args{isa} =~ /^([^\[]+)\[.+\]$/ &&
               $1 ne 'ArrayRef' &&
               $1 ne 'HashRef'  &&
               $1 ne 'Maybe'
        ;

        my $type_constraint = delete $args{isa};
        $args{type_constraint}= Mouse::Util::TypeConstraints::find_or_create_isa_type_constraint($type_constraint);
    }

    my $attribute = $self->new($name, %args);

    $attribute->_create_args(\%args);

    $class->add_attribute($attribute);

    # install an accessor
    if ($attribute->_is_metadata eq 'rw' || $attribute->_is_metadata eq 'ro') {
        my $code = Mouse::Meta::Method::Accessor->generate_accessor_method_inline(
            $attribute,
        );
        $class->add_method($name => $code);
    }

    for my $method (qw/predicate clearer/) {
        my $predicate = "has_$method";
        if ($attribute->$predicate) {
            my $generator = "generate_$method";
            my $coderef = $attribute->$generator;
            $class->add_method($attribute->$method => $coderef);
        }
    }

    if ($attribute->has_handles) {
        my $method_map = $attribute->generate_handles;
        for my $method_name (keys %$method_map) {
            $class->add_method($method_name => $method_map->{$method_name});
        }
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

    confess "You can not use lazy_build and default for the same attribute ($name)"
        if $args->{lazy_build} && exists $args->{default};

    confess "You cannot have lazy attribute ($name) without specifying a default value for it"
        if $args->{lazy}
        && !exists($args->{default})
        && !exists($args->{builder});

    confess "References are not allowed as default values, you must wrap the default of '$name' in a CODE reference (ex: sub { [] } and not [])"
        if ref($args->{default})
        && ref($args->{default}) ne 'CODE';

    confess "You cannot auto-dereference without specifying a type constraint on attribute ($name)"
        if $args->{auto_deref} && !exists($args->{isa});

    confess "You cannot auto-dereference anything other than a ArrayRef or HashRef on attribute ($name)"
        if $args->{auto_deref}
        && $args->{isa} ne 'ArrayRef'
        && $args->{isa} ne 'HashRef';

    if ($args->{trigger}) {
        if (ref($args->{trigger}) eq 'HASH') {
            Carp::carp "HASH-based form of trigger has been removed. Only the coderef form of triggers are now supported.";
        }

        confess "Trigger must be a CODE ref on attribute ($name)"
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
    Carp::confess("Attribute ($name) does not pass the type constraint because: " . $type->get_message($value));
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
        confess "Unable to canonicalize the 'handles' option with $handles";
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

    confess "Could not find an attribute by the name of '$name' to inherit from";
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

=head2 generate_accessor -> CODE

Creates a new code reference for the attribute's accessor.

=head2 generate_predicate -> CODE

Creates a new code reference for the attribute's predicate.

=head2 generate_clearer -> CODE

Creates a new code reference for the attribute's clearer.

=head2 generate_handles -> { MethodName => CODE }

Creates a new code reference for each of the attribute's handles methods.

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

