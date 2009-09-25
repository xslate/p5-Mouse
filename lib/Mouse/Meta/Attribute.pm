package Mouse::Meta::Attribute;
use strict;
use warnings;

use Carp ();
use Scalar::Util qw(weaken);

use Mouse::Util qw(:meta);

use Mouse::Meta::TypeConstraint;
use Mouse::Meta::Method::Accessor;

sub _process_options{
    my($class, $name, $args) = @_;

    # taken from Class::MOP::Attribute::new

    defined($name)
        or $class->throw_error('You must provide a name for the attribute');

    if(!exists $args->{init_arg}){
        $args->{init_arg} = $name;
    }

    # 'required' requires eigher 'init_arg', 'builder', or 'default'
    my $can_be_required = defined( $args->{init_arg} );

    if(exists $args->{builder}){
        $class->throw_error('builder must be a defined scalar value which is a method name')
            if ref $args->{builder} || !(defined $args->{builder});

        $can_be_required++;
    }
    elsif(exists $args->{default}){
        if(ref $args->{default} && ref($args->{default}) ne 'CODE'){
            $class->throw_error("References are not allowed as default values, you must "
                              . "wrap the default of '$name' in a CODE reference (ex: sub { [] } and not [])");
        }
        $can_be_required++;
    }

    if( $args->{required} && !$can_be_required ) {
        $class->throw_error("You cannot have a required attribute ($name) without a default, builder, or an init_arg");
    }

    # taken from Mouse::Meta::Attribute->new and _process_args->

    if(exists $args->{is}){
        my $is = $args->{is};

        if($is eq 'ro'){
            $args->{reader} ||= $name;
        }
        elsif($is eq 'rw'){
            if(exists $args->{writer}){
                $args->{reader} ||= $name;
             }
             else{
                $args->{accessor} ||= $name;
             }
        }
        elsif($is eq 'bare'){
            # do nothing, but don't complain (later) about missing methods
        }
        else{
            $is = 'undef' if !defined $is;
            $class->throw_error("I do not understand this option (is => $is) on attribute ($name)");
        }
    }

    my $tc;
    if(exists $args->{isa}){
        $args->{type_constraint} = Mouse::Util::TypeConstraints::find_or_create_isa_type_constraint($args->{isa});
    }
    elsif(exists $args->{does}){
        $args->{type_constraint} = Mouse::Util::TypeConstraints::find_or_create_does_type_constraint($args->{does});
    }
    $tc = $args->{type_constraint};

    if($args->{coerce}){
        defined($tc)
            || $class->throw_error("You cannot have coercion without specifying a type constraint on attribute ($name)");

        $args->{weak_ref}
            && $class->throw_error("You cannot have a weak reference to a coerced value on attribute ($name)");
    }

    if ($args->{lazy_build}) {
        exists($args->{default})
            && $class->throw_error("You can not use lazy_build and default for the same attribute ($name)");

        $args->{lazy}      = 1;
        $args->{builder} ||= "_build_${name}";
        if ($name =~ /^_/) {
            $args->{clearer}   ||= "_clear${name}";
            $args->{predicate} ||= "_has${name}";
        }
        else {
            $args->{clearer}   ||= "clear_${name}";
            $args->{predicate} ||= "has_${name}";
        }
    }

    if ($args->{auto_deref}) {
        defined($tc)
            || $class->throw_error("You cannot auto-dereference without specifying a type constraint on attribute ($name)");

        ( $tc->is_a_type_of('ArrayRef') || $tc->is_a_type_of('HashRef') )
            || $class->throw_error("You cannot auto-dereference anything other than a ArrayRef or HashRef on attribute ($name)");
    }

    if (exists $args->{trigger}) {
        ('CODE' eq ref $args->{trigger})
            || $class->throw_error("Trigger must be a CODE ref on attribute ($name)");
    }

    if ($args->{lazy}) {
        (exists $args->{default} || defined $args->{builder})
            || $class->throw_error("You cannot have lazy attribute ($name) without specifying a default value for it");
    }

    # XXX: for backward compatibility (with method modifiers)
    if($class->can('canonicalize_args') != \&canonicalize_args){
        %{$args} = $class->canonicalize_args($name, %{$args});
    }
    return;
}

sub new {
    my $class = shift;
    my $name  = shift;

    my %args  = (@_ == 1) ? %{ $_[0] } : @_;

    $class->_process_options($name, \%args);

    $args{name} = $name;

    my $instance = bless \%args, $class;

    # extra attributes
    if($class ne __PACKAGE__){
        $class->meta->_initialize_instance($instance,\%args);
    }

# XXX: there is no fast way to check attribute validity
#    my @bad = ...;
#    if(@bad){
#        @bad = sort @bad;
#        Carp::cluck("Found unknown argument(s) passed to '$name' attribute constructor in '$class': @bad");
#    }

    return $instance
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

sub trigger              { $_[0]->{trigger}                }
sub builder              { $_[0]->{builder}                }
sub should_auto_deref    { $_[0]->{auto_deref}             }
sub should_coerce        { $_[0]->{coerce}                 }

sub get_read_method      { $_[0]->{reader} || $_[0]->{accessor} }
sub get_write_method     { $_[0]->{writer} || $_[0]->{accessor} }

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

sub has_read_method      { exists $_[0]->{reader} || exists $_[0]->{accessor} }
sub has_write_method     { exists $_[0]->{writer} || exists $_[0]->{accessor} }

sub _create_args {
    $_[0]->{_create_args} = $_[1] if @_ > 1;
    $_[0]->{_create_args}
}

sub accessor_metaclass { 'Mouse::Meta::Method::Accessor' }

sub interpolate_class{
    my($class, $name, $args) = @_;

    if(my $metaclass = delete $args->{metaclass}){
        $class = Mouse::Util::resolve_metaclass_alias( Attribute => $metaclass );
    }

    my @traits;
    if(my $traits_ref = delete $args->{traits}){

        for (my $i = 0; $i < @{$traits_ref}; $i++) {
            my $trait = Mouse::Util::resolve_metaclass_alias(Attribute => $traits_ref->[$i], trait => 1);

            next if $class->does($trait);

            push @traits, $trait;

            # are there options?
            push @traits, $traits_ref->[++$i]
                if ref($traits_ref->[$i+1]);
        }

        if (@traits) {
            $class = Mouse::Meta::Class->create_anon_class(
                superclasses => [ $class ],
                roles        => \@traits,
                cache        => 1,
            )->name;
        }
    }

    return( $class, @traits );
}

sub canonicalize_args{
    my ($self, $name, %args) = @_;

    Carp::cluck("$self->canonicalize_args has been deprecated."
        . "Use \$self->_process_options instead.");

    return %args;
}

sub create {
    my ($self, $class, $name, %args) = @_;

    Carp::cluck("$self->create has been deprecated."
        . "Use \$meta->add_attribute and \$attr->install_accessors instead.");

    # noop
    return $self;
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

sub clone_and_inherit_options{
    my $self = shift;
    my $name = shift;

    return ref($self)->new($name, %{$self}, @_ == 1 ? %{$_[0]} : @_);
}

sub clone_parent {
    my $self  = shift;
    my $class = shift;
    my $name  = shift;
    my %args  = ($self->get_parent_args($class, $name), @_);

    Carp::cluck("$self->clone_parent has been deprecated."
        . "Use \$meta->add_attribute and \$attr->install_accessors instead.");


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

sub install_accessors{
    my($attribute) = @_;

    my $metaclass       = $attribute->{associated_class};
    my $generator_class = $attribute->accessor_metaclass;

    foreach my $type(qw(accessor reader writer predicate clearer handles)){
        if(exists $attribute->{$type}){
            my $installer    = '_install_' . $type;
            $generator_class->$installer($attribute, $attribute->{$type}, $metaclass);
            $attribute->{associated_methods}++;
        }
    }

    if($attribute->can('create') != \&create){
        $attribute->create($metaclass, $attribute->name, %{$attribute});
    }

    return;
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

