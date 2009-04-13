package Mouse::Meta::Class;
use strict;
use warnings;

use Mouse::Meta::Method::Constructor;
use Mouse::Meta::Method::Destructor;
use Scalar::Util qw/blessed weaken/;
use Mouse::Util qw/get_linear_isa version authority identifier/;
use Carp 'confess';

do {
    my %METACLASS_CACHE;

    # because Mouse doesn't introspect existing classes, we're forced to
    # only pay attention to other Mouse classes
    sub _metaclass_cache {
        my $class = shift;
        my $name  = shift;
        return $METACLASS_CACHE{$name};
    }

    sub initialize {
        my $class = blessed($_[0]) || $_[0];
        my $name  = $_[1];

        $METACLASS_CACHE{$name} = $class->new(name => $name)
            if !exists($METACLASS_CACHE{$name});
        return $METACLASS_CACHE{$name};
    }

    # Means of accessing all the metaclasses that have
    # been initialized thus far
    sub get_all_metaclasses         {        %METACLASS_CACHE         }
    sub get_all_metaclass_instances { values %METACLASS_CACHE         }
    sub get_all_metaclass_names     { keys   %METACLASS_CACHE         }
    sub get_metaclass_by_name       { $METACLASS_CACHE{$_[0]}         }
    sub store_metaclass_by_name     { $METACLASS_CACHE{$_[0]} = $_[1] }
    sub weaken_metaclass            { weaken($METACLASS_CACHE{$_[0]}) }
    sub does_metaclass_exist        { exists $METACLASS_CACHE{$_[0]} && defined $METACLASS_CACHE{$_[0]} }
    sub remove_metaclass_by_name    { $METACLASS_CACHE{$_[0]} = undef }
};

sub new {
    my $class = shift;
    my %args  = @_;

    $args{attributes} = {};
    $args{superclasses} = do {
        no strict 'refs';
        \@{ $args{name} . '::ISA' };
    };
    $args{roles} ||= [];

    bless \%args, $class;
}

sub name { $_[0]->{name} }

sub superclasses {
    my $self = shift;

    if (@_) {
        Mouse::load_class($_) for @_;
        @{ $self->{superclasses} } = @_;
    }

    @{ $self->{superclasses} };
}

sub add_method {
    my $self = shift;
    my $name = shift;
    my $code = shift;

    my $pkg = $self->name;

    no strict 'refs';
    no warnings 'redefine';
    $self->{'methods'}->{$name}++; # Moose stores meta object here.
    *{ $pkg . '::' . $name } = $code;
}

sub has_method {
    my $self = shift;
    my $name = shift;
    $self->name->can($name);
}

# copied from Class::Inspector
my $get_methods_for_class = sub {
    my $self = shift;
    my $name = shift;

    no strict 'refs';
    # Get all the CODE symbol table entries
    my @functions =
      grep !/^(?:has|with|around|before|after|augment|inner|blessed|extends|confess|override|super)$/,
      grep { defined &{"${name}::$_"} }
      keys %{"${name}::"};
    push @functions, keys %{$self->{'methods'}->{$name}} if $self;
    wantarray ? @functions : \@functions;
};

sub get_method_list {
    my $self = shift;
    $get_methods_for_class->($self, $self->name);
}

sub get_all_method_names {
    my $self = shift;
    my %uniq;
    return grep { $uniq{$_}++ == 0 }
            map { $get_methods_for_class->(undef, $_) }
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

sub get_attribute_map { $_[0]->{attributes} }
sub has_attribute     { exists $_[0]->{attributes}->{$_[1]} }
sub get_attribute     { $_[0]->{attributes}->{$_[1]} }
sub get_attribute_list {
    my $self = shift;
    keys %{$self->get_attribute_map};
}

sub linearized_isa { @{ get_linear_isa($_[0]->name) } }

sub clone_object {
    my $class    = shift;
    my $instance = shift;

    (blessed($instance) && $instance->isa($class->name))
        || confess "You must pass an instance of the metaclass (" . $class->name . "), not ($instance)";

    $class->clone_instance($instance, @_);
}

sub clone_instance {
    my ($class, $instance, %params) = @_;

    (blessed($instance))
        || confess "You can only clone instances, ($instance) is not a blessed instance";

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
        @_,
    );

    my $name = $self->name;
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

sub make_mutable { confess "Mouse does not currently support 'make_mutable'" }

sub is_immutable { $_[0]->{is_immutable} }

sub attribute_metaclass { "Mouse::Meta::Class" }

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
        no strict 'refs';
        no warnings 'redefine';
        *{__PACKAGE__ . '::_install_modifier'} = sub {
            my ( $self, $into, $type, $name, $code ) = @_;
            $modifier->(
                $into,
                $type,
                $name,
                $code
            );
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

    my $pkg = $self->name;
    my $method = "${pkg}::${name}";

    # Class::Method::Modifiers won't do this for us, so do it ourselves

    my $body = $pkg->can($name)
        or confess "You cannot override '$method' because it has no super method";

    no strict 'refs';
    *$method = sub { $code->($pkg, $body, @_) };
}


sub roles { $_[0]->{roles} }

sub does_role {
    my ($self, $role_name) = @_;

    (defined $role_name)
        || confess "You must supply a role name to look for";

    for my $class ($self->linearized_isa) {
        next unless $class->can('meta') and $class->meta->can('roles');
        for my $role (@{ $class->meta->roles }) {
            return 1 if $role->name eq $role_name;
        }
    }

    return 0;
}

sub create {
    my ($self, $package_name, %options) = @_;

    (ref $options{superclasses} eq 'ARRAY')
        || confess "You must pass an ARRAY ref of superclasses"
            if exists $options{superclasses};

    (ref $options{attributes} eq 'ARRAY')
        || confess "You must pass an ARRAY ref of attributes"
            if exists $options{attributes};

    (ref $options{methods} eq 'HASH')
        || confess "You must pass a HASH ref of methods"
            if exists $options{methods};

    do {
        ( defined $package_name && $package_name )
          || confess "You must pass a package name";

        my $code = "package $package_name;";
        $code .= "\$$package_name\:\:VERSION = '" . $options{version} . "';"
          if exists $options{version};
        $code .= "\$$package_name\:\:AUTHORITY = '" . $options{authority} . "';"
          if exists $options{authority};

        eval $code;
        confess "creation of $package_name failed : $@" if $@;
    };

    my %initialize_options = %options;
    delete @initialize_options{qw(
        package
        superclasses
        attributes
        methods
        version
        authority
    )};
    my $meta = $self->initialize( $package_name => %initialize_options );

    # FIXME totally lame
    $meta->add_method('meta' => sub {
        $self->initialize(ref($_[0]) || $_[0]);
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
    sub create_anon_class {
        my ( $class, %options ) = @_;
        my $package_name = $ANON_CLASS_PREFIX . ++$ANON_CLASS_SERIAL;
        return $class->create( $package_name, %options );
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

