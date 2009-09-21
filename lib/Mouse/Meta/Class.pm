package Mouse::Meta::Class;
use strict;
use warnings;

use Mouse::Meta::Method::Constructor;
use Mouse::Meta::Method::Destructor;
use Scalar::Util qw/blessed weaken/;
use Mouse::Util qw/get_linear_isa not_supported/;

use base qw(Mouse::Meta::Module);

sub method_metaclass(){ 'Mouse::Meta::Method' } # required for get_method()

sub _new {
    my($class, %args) = @_;

    $args{attributes} ||= {};
    $args{methods}    ||= {};
    $args{roles}      ||= [];

    $args{superclasses} = do {
        no strict 'refs';
        \@{ $args{package} . '::ISA' };
    };

    bless \%args, $class;
}

sub roles { $_[0]->{roles} }

sub superclasses {
    my $self = shift;

    if (@_) {
        Mouse::load_class($_) for @_;
        @{ $self->{superclasses} } = @_;
    }

    @{ $self->{superclasses} };
}

sub get_all_method_names {
    my $self = shift;
    my %uniq;
    return grep { $uniq{$_}++ == 0 }
            map { Mouse::Meta::Class->initialize($_)->get_method_list() }
            $self->linearized_isa;
}

sub add_attribute {
    my $self = shift;

    if (@_ == 1 && blessed($_[0])) {
        my $attr = shift @_;
        $self->{'attributes'}{$attr->name} = $attr;
    } else {
        my $names = shift @_;
        $names = [$names] if !ref($names);
        my $metaclass = 'Mouse::Meta::Attribute';
        my %options = @_;

        if ( my $metaclass_name = delete $options{metaclass} ) {
            my $new_class = Mouse::Util::resolve_metaclass_alias(
                'Attribute',
                $metaclass_name
            );
            if ( $metaclass ne $new_class ) {
                $metaclass = $new_class;
            }
        }

        for my $name (@$names) {
            if ($name =~ s/^\+//) {
                $metaclass->clone_parent($self, $name, @_);
            }
            else {
                $metaclass->create($self, $name, @_);
            }
        }
    }
}

sub compute_all_applicable_attributes { shift->get_all_attributes(@_) }
sub get_all_attributes {
    my $self = shift;
    my (@attr, %seen);

    for my $class ($self->linearized_isa) {
        my $meta = $self->_metaclass_cache($class)
            or next;

        for my $name (keys %{ $meta->get_attribute_map }) {
            next if $seen{$name}++;
            push @attr, $meta->get_attribute($name);
        }
    }

    return @attr;
}

sub linearized_isa { @{ get_linear_isa($_[0]->name) } }

sub new_object {
    my $self = shift;
    my $args = (@_ == 1) ? $_[0] : { @_ };

    my $instance = bless {}, $self->name;

    foreach my $attribute ($self->get_all_attributes) {
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
                    $self->throw_error("Attribute (".$attribute->name.") is required");
                }
            }
        }
    }
    return $instance;
}

sub clone_object {
    my $class    = shift;
    my $instance = shift;

    (blessed($instance) && $instance->isa($class->name))
        || $class->throw_error("You must pass an instance of the metaclass (" . $class->name . "), not ($instance)");

    $class->clone_instance($instance, @_);
}

sub clone_instance {
    my ($class, $instance, %params) = @_;

    (blessed($instance))
        || $class->throw_error("You can only clone instances, ($instance) is not a blessed instance");

    my $clone = bless { %$instance }, ref $instance;

    foreach my $attr ($class->get_all_attributes()) {
        if ( defined( my $init_arg = $attr->init_arg ) ) {
            if (exists $params{$init_arg}) {
                $clone->{ $attr->name } = $params{$init_arg};
            }
        }
    }

    return $clone;

}

sub make_immutable {
    my $self = shift;
    my %args = (
        inline_constructor => 1,
        inline_destructor  => 1,
        @_,
    );

    $self->{is_immutable}++;

    if ($args{inline_constructor}) {
        $self->add_method('new' => Mouse::Meta::Method::Constructor->generate_constructor_method_inline( $self ));
    }

    if ($args{inline_destructor}) {
        $self->add_method('DESTROY' => Mouse::Meta::Method::Destructor->generate_destructor_method_inline( $self ));
    }

    # Moose's make_immutable returns true allowing calling code to skip setting an explicit true value
    # at the end of a source file. 
    return 1;
}

sub make_mutable { not_supported }

sub is_immutable {  $_[0]->{is_immutable} }
sub is_mutable   { !$_[0]->{is_immutable} }

sub _install_modifier {
    my ( $self, $into, $type, $name, $code ) = @_;

    # which is modifer class available?
    my $modifier_class = do {
        if (eval "require Class::Method::Modifiers::Fast; 1") {
            'Class::Method::Modifiers::Fast';
        } elsif (eval "require Class::Method::Modifiers; 1") {
            'Class::Method::Modifiers';
        } else {
            Carp::croak("Method modifiers require the use of Class::Method::Modifiers or Class::Method::Modifiers::Fast. Please install it from CPAN and file a bug report with this application.");
        }
    };
    my $modifier = $modifier_class->can('_install_modifier');

    # replace this method itself :)
    {
        no warnings 'redefine';
        *_install_modifier = sub {
            my ( $self, $into, $type, $name, $code ) = @_;
            $modifier->(
                $into,
                $type,
                $name,
                $code
            );
            $self->{methods}{$name}++; # register it to the method map
            return;
        };
    }

    # call me. for first time.
    $self->_install_modifier( $into, $type, $name, $code );
}

sub add_before_method_modifier {
    my ( $self, $name, $code ) = @_;
    $self->_install_modifier( $self->name, 'before', $name, $code );
}

sub add_around_method_modifier {
    my ( $self, $name, $code ) = @_;
    $self->_install_modifier( $self->name, 'around', $name, $code );
}

sub add_after_method_modifier {
    my ( $self, $name, $code ) = @_;
    $self->_install_modifier( $self->name, 'after', $name, $code );
}

sub add_override_method_modifier {
    my ($self, $name, $code) = @_;

    my $package = $self->name;

    my $body = $package->can($name)
        or $self->throw_error("You cannot override '$name' because it has no super method");

    $self->add_method($name => sub { $code->($package, $body, @_) });
}

sub does_role {
    my ($self, $role_name) = @_;

    (defined $role_name)
        || $self->throw_error("You must supply a role name to look for");

    for my $class ($self->linearized_isa) {
        my $meta = Mouse::class_of($class);
        next unless $meta && $meta->can('roles');

        for my $role (@{ $meta->roles }) {
            return 1 if $role->does_role($role_name);
        }
    }

    return 0;
}

sub create {
    my ($class, $package_name, %options) = @_;

    (ref $options{superclasses} eq 'ARRAY')
        || $class->throw_error("You must pass an ARRAY ref of superclasses")
            if exists $options{superclasses};

    (ref $options{attributes} eq 'ARRAY')
        || $class->throw_error("You must pass an ARRAY ref of attributes")
            if exists $options{attributes};

    (ref $options{methods} eq 'HASH')
        || $class->throw_error("You must pass a HASH ref of methods")
            if exists $options{methods};

    {
        ( defined $package_name && $package_name )
          || $class->throw_error("You must pass a package name");

        no strict 'refs';
        ${ $package_name . '::VERSION'   } = $options{version}   if exists $options{version};
        ${ $package_name . '::AUTHORITY' } = $options{authority} if exists $options{authority};
    }

    my %initialize_options = %options;
    delete @initialize_options{qw(
        package
        superclasses
        attributes
        methods
        version
        authority
    )};
    my $meta = $class->initialize( $package_name => %initialize_options );

    # FIXME totally lame
    $meta->add_method('meta' => sub {
        Mouse::Meta::Class->initialize(ref($_[0]) || $_[0]);
    });

    $meta->superclasses(@{$options{superclasses}})
        if exists $options{superclasses};
    # NOTE:
    # process attributes first, so that they can
    # install accessors, but locally defined methods
    # can then overwrite them. It is maybe a little odd, but
    # I think this should be the order of things.
    if (exists $options{attributes}) {
        foreach my $attr (@{$options{attributes}}) {
            Mouse::Meta::Attribute->create($meta, $attr->{name}, %$attr);
        }
    }
    if (exists $options{methods}) {
        foreach my $method_name (keys %{$options{methods}}) {
            $meta->add_method($method_name, $options{methods}->{$method_name});
        }
    }
    return $meta;
}

{
    my $ANON_CLASS_SERIAL = 0;
    my $ANON_CLASS_PREFIX = 'Mouse::Meta::Class::__ANON__::SERIAL::';

    my %IMMORTAL_ANON_CLASSES;
    sub create_anon_class {
        my ( $class, %options ) = @_;

        my $cache = $options{cache};
        my $cache_key;

        if($cache){ # anonymous but not mortal
                # something like Super::Class|Super::Class::2=Role|Role::1
                $cache_key = join '=' => (
                    join('|', @{$options{superclasses} || []}),
                    join('|', sort @{$options{roles}   || []}),
                );
                return $IMMORTAL_ANON_CLASSES{$cache_key} if exists $IMMORTAL_ANON_CLASSES{$cache_key};
        }
        my $package_name = $ANON_CLASS_PREFIX . ++$ANON_CLASS_SERIAL;
        my $meta = $class->create( $package_name, anon_class_id => $ANON_CLASS_SERIAL, %options );

        if($cache){
            $IMMORTAL_ANON_CLASSES{$cache_key} = $meta;
        }
        else{
            Mouse::Meta::Module::weaken_metaclass($package_name);
        }
        return $meta;
    }

    sub is_anon_class{
        return exists $_[0]->{anon_class_id};
    }


    sub DESTROY{
        my($self) = @_;

        my $serial_id = $self->{anon_class_id};

        return if !$serial_id;

        my $stash = $self->namespace;

        @{$self->{sperclasses}} = ();
        %{$stash} = ();
        Mouse::Meta::Module::remove_metaclass_by_name($self->name);

        no strict 'refs';
        delete ${$ANON_CLASS_PREFIX}{ $serial_id . '::' };

        return;
    }

}

1;

__END__

=head1 NAME

Mouse::Meta::Class - hook into the Mouse MOP

=head1 METHODS

=head2 initialize ClassName -> Mouse::Meta::Class

Finds or creates a Mouse::Meta::Class instance for the given ClassName. Only
one instance should exist for a given class.

=head2 new %args -> Mouse::Meta::Class

Creates a new Mouse::Meta::Class. Don't call this directly.

=head2 name -> ClassName

Returns the name of the owner class.

=head2 superclasses -> [ClassName]

Gets (or sets) the list of superclasses of the owner class.

=head2 add_attribute (Mouse::Meta::Attribute| name => spec)

Begins keeping track of the existing L<Mouse::Meta::Attribute> for the owner
class.

=head2 get_all_attributes -> (Mouse::Meta::Attribute)

Returns the list of all L<Mouse::Meta::Attribute> instances associated with
this class and its superclasses.

=head2 get_attribute_map -> { name => Mouse::Meta::Attribute }

Returns a mapping of attribute names to their corresponding
L<Mouse::Meta::Attribute> objects.

=head2 get_attribute_list -> { name => Mouse::Meta::Attribute }

This returns a list of attribute names which are defined in the local
class. If you want a list of all applicable attributes for a class,
use the C<get_all_attributes> method.

=head2 has_attribute Name -> Bool

Returns whether we have a L<Mouse::Meta::Attribute> with the given name.

=head2 get_attribute Name -> Mouse::Meta::Attribute | undef

Returns the L<Mouse::Meta::Attribute> with the given name.

=head2 linearized_isa -> [ClassNames]

Returns the list of classes in method dispatch order, with duplicates removed.

=head2 clone_object Instance -> Instance

Clones the given C<Instance> which must be an instance governed by this
metaclass.

=head2 clone_instance Instance, Parameters -> Instance

The clone_instance method has been made private.
The public version is deprecated.

=cut

