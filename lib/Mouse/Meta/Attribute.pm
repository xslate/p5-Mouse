#!/usr/bin/env perl
package Mouse::Meta::Attribute;
use strict;
use warnings;

use Carp 'confess';
use Scalar::Util 'blessed';

sub new {
    my $class = shift;
    my %args  = @_;

    my $name = $args{name};

    $args{init_arg} = $name
        unless exists $args{init_arg};

    $args{is} ||= '';

    if ($args{lazy_build}) {
        confess("You can not use lazy_build and default for the same attribute $name")
            if exists $args{default};
        $args{lazy}      = 1;
        $args{required}  = 1;
        $args{builder} ||= "_build_${name}";
        if ($name =~ /^_/) {
            $args{clearer}   ||= "_clear${name}";
            $args{predicate} ||= "_has${name}";
        } 
        else {
            $args{clearer}   ||= "clear_${name}";
            $args{predicate} ||= "has_${name}";
        }
    }

    bless \%args, $class;
}

sub name              { $_[0]->{name}            }
sub class             { $_[0]->{class}           }
sub _is_metadata      { $_[0]->{is}              }
sub is_required       { $_[0]->{required}        }
sub default           { $_[0]->{default}         }
sub is_lazy           { $_[0]->{lazy}            }
sub is_lazy_build     { $_[0]->{lazy_build}      }
sub predicate         { $_[0]->{predicate}       }
sub clearer           { $_[0]->{clearer}         }
sub handles           { $_[0]->{handles}         }
sub is_weak_ref       { $_[0]->{weak_ref}        }
sub init_arg          { $_[0]->{init_arg}        }
sub type_constraint   { $_[0]->{type_constraint} }
sub trigger           { $_[0]->{trigger}         }
sub builder           { $_[0]->{builder}         }
sub should_auto_deref { $_[0]->{auto_deref}      }

sub has_default         { exists $_[0]->{default}         }
sub has_predicate       { exists $_[0]->{predicate}       }
sub has_clearer         { exists $_[0]->{clearer}         }
sub has_handles         { exists $_[0]->{handles}         }
sub has_type_constraint { exists $_[0]->{type_constraint} }
sub has_trigger         { exists $_[0]->{trigger}         }
sub has_builder         { exists $_[0]->{builder}         }

sub _create_args {
    $_[0]->{_create_args} = $_[1] if @_ > 1;
    $_[0]->{_create_args}
}

sub generate_accessor {
    my $attribute = shift;

    my $name       = $attribute->name;
    my $key        = $name;
    my $default    = $attribute->default;
    my $trigger    = $attribute->trigger;
    my $type       = $attribute->type_constraint;
    my $constraint = $attribute->find_type_constraint;
    my $builder    = $attribute->builder;

    my $accessor = 'sub {
        my $self = shift;';

    if ($attribute->_is_metadata eq 'rw') {
        $accessor .= 'if (@_) {
            local $_ = $_[0];';

        if ($constraint) {
            $accessor .= 'do {
                my $display = defined($_) ? overload::StrVal($_) : "undef";
                Carp::confess("Attribute ($name) does not pass the type constraint because: Validation failed for \'$type\' failed with value $display") unless $constraint->();
            };'
        }

        $accessor .= '$self->{$key} = $_;';

        if ($attribute->is_weak_ref) {
            $accessor .= 'Scalar::Util::weaken($self->{$key}) if ref($self->{$key});';
        }

        if ($trigger) {
            $accessor .= '$trigger->($self, $_, $attribute);';
        }

        $accessor .= '}';
    }
    else {
        $accessor .= 'confess "Cannot assign a value to a read-only accessor" if @_;';
    }

    if ($attribute->is_lazy) {
        $accessor .= '$self->{$key} = ';

        $accessor .= $attribute->has_builder
                   ? '$self->$builder'
                     : ref($default) eq 'CODE'
                     ? '$default->($self)'
                     : '$default';

        $accessor .= ' if !exists($self->{$key});';
    }

    if ($attribute->should_auto_deref) {
        if ($attribute->type_constraint eq 'ArrayRef') {
            $accessor .= 'if (wantarray) {
                return @{ $self->{$key} || [] };
            }';
        }
        else {
            $accessor .= 'if (wantarray) {
                return %{ $self->{$key} || {} };
            }';
        }
    }

    $accessor .= 'return $self->{$key};
    }';

    return eval $accessor;
}

sub generate_predicate {
    my $attribute = shift;
    my $key = $attribute->name;

    my $predicate = 'sub { exists($_[0]->{$key}) }';

    return eval $predicate;
}

sub generate_clearer {
    my $attribute = shift;
    my $key = $attribute->name;

    my $predicate = 'sub { delete($_[0]->{$key}) }';

    return eval $predicate;
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
            $self->$reader->$remote_method(@_)
        }';

        $method_map{$local_method} = eval $method;
    }

    return \%method_map;
}

sub create {
    my ($self, $class, $name, %args) = @_;

    $args{name} = $name;
    $args{class} = $class;

    $self->validate_args($name, %args);

    $args{type_constraint} = delete $args{isa}
        if exists $args{isa};

    my $attribute = $self->new(%args);
    $attribute->_create_args(\%args);

    my $meta = $class->meta;

    $meta->add_attribute($attribute);

    # install an accessor
    if ($attribute->_is_metadata eq 'rw' || $attribute->_is_metadata eq 'ro') {
        my $accessor = $attribute->generate_accessor;
        no strict 'refs';
        *{ $class . '::' . $name } = $accessor;
    }

    for my $method (qw/predicate clearer/) {
        my $predicate = "has_$method";
        if ($attribute->$predicate) {
            my $generator = "generate_$method";
            my $coderef = $attribute->$generator;
            no strict 'refs';
            *{ $class . '::' . $attribute->$method } = $coderef;
        }
    }

    if ($attribute->has_handles) {
        my $method_map = $attribute->generate_handles;
        for my $method_name (keys %$method_map) {
            no strict 'refs';
            *{ $class . '::' . $method_name } = $method_map->{$method_name};
        }
    }

    return $attribute;
}

sub validate_args {
    my $self = shift;
    my $name = shift;
    my %args = @_;

    confess "You cannot have lazy attribute ($name) without specifying a default value for it"
        if $args{lazy} && !exists($args{default}) && !exists($args{builder});

    confess "References are not allowed as default values, you must wrap the default of '$name' in a CODE reference (ex: sub { [] } and not [])"
        if ref($args{default})
        && ref($args{default}) ne 'CODE';

    confess "You cannot auto-dereference without specifying a type constraint on attribute $name"
        if $args{auto_deref} && !exists($args{isa});

    confess "You cannot auto-dereference anything other than a ArrayRef or HashRef on attribute $name"
        if $args{auto_deref}
        && $args{isa} ne 'ArrayRef'
        && $args{isa} ne 'HashRef';

    return 1;
}

sub find_type_constraint {
    my $self = shift;
    my $type = $self->type_constraint;

    return unless $type;

    my $checker = Mouse::TypeRegistry->optimized_constraints->{$type};
    return $checker if $checker;

    return sub { blessed($_) && blessed($_) eq $type };
}

sub verify_type_constraint {
    my $self = shift;
    local $_ = shift;

    my $type = $self->type_constraint
        or return 1;
    my $constraint = $self->find_type_constraint;

    return 1 if $constraint->($_);

    my $name = $self->name;
    my $display = defined($_) ? overload::StrVal($_) : 'undef';
    Carp::confess("Attribute ($name) does not pass the type constraint because: Validation failed for \'$type\' failed with value $display");
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

    for my $super ($class->meta->linearized_isa) {
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

=head2 class -> OwnerClass

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

=head2 find_type_constraint -> CODE

Returns a code reference which can be used to check that a given value passes
this attribute's type constraint;

=head2 verify_type_constraint Item -> 1 | ERROR

Checks that the given value passes this attribute's type constraint. Returns 1
on success, otherwise C<confess>es.

=cut

