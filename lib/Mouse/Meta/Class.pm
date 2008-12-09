package Mouse::Meta::Class;
use strict;
use warnings;

use Mouse::Meta::Method::Constructor;
use Mouse::Meta::Method::Destructor;
use Scalar::Util qw/blessed/;
use Mouse::Util qw/get_linear_isa/;
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
        my $class = shift;
        my $name  = shift;
        $METACLASS_CACHE{$name} = $class->new(name => $name)
            if !exists($METACLASS_CACHE{$name});
        return $METACLASS_CACHE{$name};
    }
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
    $self->{'methods'}->{$name}++; # Moose stores meta object here.
    *{ $pkg . '::' . $name } = $code;
}

# copied from Class::Inspector
sub get_method_list {
    my $self = shift;
    my $name = $self->name;

    no strict 'refs';
    # Get all the CODE symbol table entries
    my @functions =
      grep !/^(?:has|with|around|before|after|blessed|extends|confess)$/,
      grep { defined &{"${name}::$_"} }
      keys %{"${name}::"};
    push @functions, keys %{$self->{'methods'}->{$name}};
    wantarray ? @functions : \@functions;
}

sub add_attribute {
    my $self = shift;
    my $attr = shift;

    $self->{'attributes'}{$attr->name} = $attr;
}

sub compute_all_applicable_attributes {
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

    foreach my $attr ($class->compute_all_applicable_attributes()) {
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
    my %args = @_;
    my $name = $self->name;
    $self->{is_immutable}++;
    $self->add_method('new' => Mouse::Meta::Method::Constructor->generate_constructor_method_inline( $self ));
    if ($args{inline_destructor}) {
        $self->add_method('DESTROY' => Mouse::Meta::Method::Destructor->generate_destructor_method_inline( $self ));
    }
}

sub make_mutable { confess "Mouse does not currently support 'make_mutable'" }

sub is_immutable { $_[0]->{is_immutable} }

sub attribute_metaclass { "Mouse::Meta::Class" }

sub add_before_method_modifier {
    my ($self, $name, $code) = @_;
    require Class::Method::Modifiers;
    Class::Method::Modifiers::_install_modifier(
        $self->name,
        'before',
        $name,
        $code,
    );
}

sub add_around_method_modifier {
    my ($self, $name, $code) = @_;
    require Class::Method::Modifiers;
    Class::Method::Modifiers::_install_modifier(
        $self->name,
        'around',
        $name,
        $code,
    );
}

sub add_after_method_modifier {
    my ($self, $name, $code) = @_;
    require Class::Method::Modifiers;
    Class::Method::Modifiers::_install_modifier(
        $self->name,
        'after',
        $name,
        $code,
    );
}

sub roles { $_[0]->{roles} }

sub does_role {
    my ($self, $role_name) = @_;

    (defined $role_name)
        || confess "You must supply a role name to look for";

    for my $role (@{ $self->{roles} }) {
        return 1 if $role->name eq $role_name;
    }

    return 0;
}

sub create {
    my ( $class, @args ) = @_;

    unshift @args, 'package' if @args % 2 == 1;

    my (%options) = @args;
    my $package_name = $options{package};

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
        # XXX should I implement Mouse::Meta::Module?
        my $package_name = $options{package};

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

    my (%initialize_options) = @args;
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
        $class->initialize(ref($_[0]) || $_[0]);
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

=head2 add_attribute Mouse::Meta::Attribute

Begins keeping track of the existing L<Mouse::Meta::Attribute> for the owner
class.

=head2 compute_all_applicable_attributes -> (Mouse::Meta::Attribute)

Returns the list of all L<Mouse::Meta::Attribute> instances associated with
this class and its superclasses.

=head2 get_attribute_map -> { name => Mouse::Meta::Attribute }

Returns a mapping of attribute names to their corresponding
L<Mouse::Meta::Attribute> objects.

=head2 has_attribute Name -> Boool

Returns whether we have a L<Mouse::Meta::Attribute> with the given name.

=head2 get_attribute Name -> Mouse::Meta::Attribute | undef

Returns the L<Mouse::Meta::Attribute> with the given name.

=head2 linearized_isa -> [ClassNames]

Returns the list of classes in method dispatch order, with duplicates removed.

=head2 clone_object Instance -> Instance

Clones the given C<Instance> which must be an instance governed by this
metaclass.

=head2 clone_instance Instance, Parameters -> Instance

Clones the given C<Instance> and sets any additional parameters.

=cut

