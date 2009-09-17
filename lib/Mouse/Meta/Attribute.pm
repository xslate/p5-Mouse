package Mouse::Meta::Attribute;
use strict;
use warnings;

use Carp 'confess';
use Scalar::Util ();
use Mouse::Meta::TypeConstraint;

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

sub _inlined_name {
    my $self = shift;
    return sprintf '"%s"', quotemeta $self->name;
}

sub _generate_accessor{
    my ($attribute) = @_;

    my $name          = $attribute->name;
    my $default       = $attribute->default;
    my $constraint    = $attribute->type_constraint;
    my $builder       = $attribute->builder;
    my $trigger       = $attribute->trigger;
    my $is_weak       = $attribute->is_weak_ref;
    my $should_deref  = $attribute->should_auto_deref;
    my $should_coerce = $attribute->should_coerce;

    my $compiled_type_constraint    = $constraint ? $constraint->{_compiled_type_constraint} : undef;

    my $self  = '$_[0]';
    my $key   = $attribute->_inlined_name;

    my $accessor = 
        '#line ' . __LINE__ . ' "' . __FILE__ . "\"\n" .
        "sub {\n";
    if ($attribute->_is_metadata eq 'rw') {
        $accessor .= 
            '#line ' . __LINE__ . ' "' . __FILE__ . "\"\n" .
            'if (scalar(@_) >= 2) {' . "\n";

        my $value = '$_[1]';

        if ($constraint) {
            if ($should_coerce) {
                $accessor .=
                    "\n".
                    '#line ' . __LINE__ . ' "' . __FILE__ . "\"\n" .
                    'my $val = Mouse::Util::TypeConstraints->typecast_constraints("'.$attribute->associated_class->name.'", $attribute->{type_constraint}, '.$value.');';
                $value = '$val';
            }
            if ($compiled_type_constraint) {
                $accessor .= 
                    "\n".
                    '#line ' . __LINE__ . ' "' . __FILE__ . "\"\n" .
                    'unless ($compiled_type_constraint->('.$value.')) {
                        $attribute->verify_type_constraint_error($name, '.$value.', $attribute->{type_constraint});
                    }' . "\n";
            } else {
                $accessor .= 
                    "\n".
                    '#line ' . __LINE__ . ' "' . __FILE__ . "\"\n" .
                    'unless ($constraint->check('.$value.')) {
                        $attribute->verify_type_constraint_error($name, '.$value.', $attribute->{type_constraint});
                    }' . "\n";
            }
        }

        # if there's nothing left to do for the attribute we can return during
        # this setter
        $accessor .= 'return ' if !$is_weak && !$trigger && !$should_deref;

        $accessor .= $self.'->{'.$key.'} = '.$value.';' . "\n";

        if ($is_weak) {
            $accessor .= 'Scalar::Util::weaken('.$self.'->{'.$key.'}) if ref('.$self.'->{'.$key.'});' . "\n";
        }

        if ($trigger) {
            $accessor .= '$trigger->('.$self.', '.$value.');' . "\n";
        }

        $accessor .= "}\n";
    }
    else {
        $accessor .= 'Carp::confess("Cannot assign a value to a read-only accessor") if scalar(@_) >= 2;' . "\n";
    }

    if ($attribute->is_lazy) {
        $accessor .= $self.'->{'.$key.'} = ';

        $accessor .= $attribute->has_builder
                ? $self.'->$builder'
                    : ref($default) eq 'CODE'
                    ? '$default->('.$self.')'
                    : '$default';
        $accessor .= ' if !exists '.$self.'->{'.$key.'};' . "\n";
    }

    if ($should_deref) {
        if (ref($constraint) && $constraint->name =~ '^ArrayRef\b') {
            $accessor .= 'if (wantarray) {
                return @{ '.$self.'->{'.$key.'} || [] };
            }';
        }
        else {
            $accessor .= 'if (wantarray) {
                return %{ '.$self.'->{'.$key.'} || {} };
            }';
        }
    }

    $accessor .= 'return '.$self.'->{'.$key.'};
    }';

    my $sub = eval $accessor;
    Carp::confess($@) if $@;
    return $sub;
}


sub _generate_predicate {
    my $attribute = shift;
    my $key = $attribute->_inlined_name;

    my $predicate = 'sub { exists($_[0]->{'.$key.'}) }';

    my $sub = eval $predicate;
    confess $@ if $@;
    return $sub;
}

sub _generate_clearer {
    my $attribute = shift;
    my $key = $attribute->_inlined_name;

    my $clearer = 'sub { delete($_[0]->{'.$key.'}) }';

    my $sub = eval $clearer;
    confess $@ if $@;
    return $sub;
}

sub _generate_handles {
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
        my $type_constraint = delete $args{isa};
        $args{type_constraint}= Mouse::Util::TypeConstraints::find_or_create_isa_type_constraint($type_constraint);
    }

    my $attribute = $self->new($name, %args);

    $attribute->_create_args(\%args);

    $class->add_attribute($attribute);

    my $associated_methods = 0;

    my $is_metadata = $attribute->_is_metadata || '';

    # install an accessor
    if ($is_metadata eq 'rw' || $is_metadata eq 'ro') {
        my $code = $attribute->_generate_accessor();
        $class->add_method($name => $code);
        $associated_methods++;
    }

    for my $method (qw/predicate clearer/) {
        my $predicate = "has_$method";
        if ($attribute->$predicate) {
            my $generator = "_generate_$method";
            my $coderef = $attribute->$generator;
            $class->add_method($attribute->$method => $coderef);
            $associated_methods++;
        }
    }

    if ($attribute->has_handles) {
        my $method_map = $attribute->_generate_handles;
        for my $method_name (keys %$method_map) {
            $class->add_method($method_name => $method_map->{$method_name});
            $associated_methods++;
        }
    }

    if($associated_methods == 0 && $is_metadata ne 'bare'){
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
        && $args->{isa} !~ /^(?:ArrayRef|HashRef)(?:\[.*\])?$/;

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

