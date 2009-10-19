package Mouse::Meta::Module;
use Mouse::Util qw/:meta get_code_package load_class not_supported/; # enables strict and warnings

use Carp ();
use Scalar::Util qw/blessed weaken/;

my %METAS;

sub _metaclass_cache { # DEPRECATED
    my($class, $name) = @_;
    return $METAS{$name};
}

sub initialize {
    my($class, $package_name, @args) = @_;

    ($package_name && !ref($package_name))
        || $class->throw_error("You must pass a package name and it cannot be blessed");

    return $METAS{$package_name}
        ||= $class->_construct_meta(package => $package_name, @args);
}

sub class_of{
    my($class_or_instance) = @_;
    return undef unless defined $class_or_instance;
    return $METAS{ ref($class_or_instance) || $class_or_instance };
}

# Means of accessing all the metaclasses that have
# been initialized thus far
#sub get_all_metaclasses         {        %METAS         }
sub get_all_metaclass_instances { values %METAS         }
sub get_all_metaclass_names     { keys   %METAS         }
sub get_metaclass_by_name       { $METAS{$_[0]}         }
#sub store_metaclass_by_name     { $METAS{$_[0]} = $_[1] }
#sub weaken_metaclass            { weaken($METAS{$_[0]}) }
#sub does_metaclass_exist        { defined $METAS{$_[0]} }
#sub remove_metaclass_by_name    { delete $METAS{$_[0]}  }



sub name { $_[0]->{package} }

# The followings are Class::MOP specific methods

#sub version   { no strict 'refs'; ${shift->name.'::VERSION'}   }
#sub authority { no strict 'refs'; ${shift->name.'::AUTHORITY'} }
#sub identifier {
#    my $self = shift;
#    return join '-' => (
#       $self->name,
#        ($self->version   || ()),
#        ($self->authority || ()),
#    );
#}

# add_attribute is an abstract method

sub get_attribute_map { # DEPRECATED
    Carp::cluck('get_attribute_map() has been deprecated');
    return $_[0]->{attributes};
}

sub has_attribute     { exists $_[0]->{attributes}->{$_[1]} }
sub get_attribute     {        $_[0]->{attributes}->{$_[1]} }
sub get_attribute_list{ keys %{$_[0]->{attributes}}         }
sub remove_attribute  { delete $_[0]->{attributes}->{$_[1]} }

sub namespace{
    my $name = $_[0]->{package};
    no strict 'refs';
    return \%{ $name . '::' };
}

sub add_method {
    my($self, $name, $code) = @_;

    if(!defined $name){
        $self->throw_error('You must pass a defined name');
    }
    if(!defined $code){
        $self->throw_error('You must pass a defined code');
    }

    if(ref($code) ne 'CODE'){
        $code = \&{$code}; # coerce
    }

    $self->{methods}->{$name} = $code; # Moose stores meta object here.

    my $pkg = $self->name;
    no strict 'refs';
    no warnings 'redefine', 'once';
    *{ $pkg . '::' . $name } = $code;
}

# XXX: for backward compatibility
my %foreign = map{ $_ => undef } qw(
    Mouse Mouse::Role Mouse::Util Mouse::Util::TypeConstraints
    Carp Scalar::Util
);
sub _code_is_mine{
    my($self, $code) = @_;

    my $package = get_code_package($code);

    return !exists $foreign{$package};
}

sub has_method {
    my($self, $method_name) = @_;

    defined($method_name)
        or $self->throw_error('You must define a method name');

    return 1 if $self->{methods}{$method_name};

    my $code = do{
        no strict 'refs';
        no warnings 'once';
        *{ $self->{package} . '::' . $method_name }{CODE};
    };

    return $code && $self->_code_is_mine($code);
}

sub get_method_body{
    my($self, $method_name) = @_;

    defined($method_name)
        or $self->throw_error('You must define a method name');

    return $self->{methods}{$method_name} ||= do{
        my $code = do{
            no strict 'refs';
            no warnings 'once';
            *{$self->{package} . '::' . $method_name}{CODE};
        };

        ($code && $self->_code_is_mine($code)) ? $code : undef;
    };
}

sub get_method{
    my($self, $method_name) = @_;

    if($self->has_method($method_name)){
        my $method_metaclass = $self->method_metaclass;
        load_class($method_metaclass);

        my $package = $self->name;
        return $method_metaclass->new(
            body    => $package->can($method_name),
            name    => $method_name,
            package => $package,
        );
    }

    return undef;
}

sub get_method_list {
    my($self) = @_;

    return grep { $self->has_method($_) } keys %{ $self->namespace };
}

{
    my $ANON_SERIAL = 0;

    my %IMMORTALS;

    sub create {
        my($self, $package_name, %options) = @_;

        my $class = ref($self) || $self;
        $self->throw_error('You must pass a package name') if @_ < 2;

        my $superclasses;
        if(exists $options{superclasses}){
            if($self->isa('Mouse::Meta::Role')){
                delete $options{superclasses};
            }
            else{
                $superclasses = delete $options{superclasses};
                (ref $superclasses eq 'ARRAY')
                    || $self->throw_error("You must pass an ARRAY ref of superclasses");
            }
        }

        my $attributes = delete $options{attributes};
        if(defined $attributes){
            (ref $attributes eq 'ARRAY' || ref $attributes eq 'HASH')
                || $self->throw_error("You must pass an ARRAY ref of attributes");
        }
        my $methods = delete $options{methods};
        if(defined $methods){
            (ref $methods eq 'HASH')
                || $self->throw_error("You must pass a HASH ref of methods");
        }
        my $roles = delete $options{roles};
        if(defined $roles){
            (ref $roles eq 'ARRAY')
                || $self->throw_error("You must pass an ARRAY ref of roles");
        }
        my $mortal;
        my $cache_key;

        if(!defined $package_name){ # anonymous
            $mortal = !$options{cache};

            # anonymous but immortal
            if(!$mortal){
                    # something like Super::Class|Super::Class::2=Role|Role::1
                    $cache_key = join '=' => (
                        join('|',      @{$superclasses || []}),
                        join('|', sort @{$roles        || []}),
                    );
                    return $IMMORTALS{$cache_key} if exists $IMMORTALS{$cache_key};
            }
            $options{anon_serial_id} = ++$ANON_SERIAL;
            $package_name = $class . '::__ANON__::' . $ANON_SERIAL;
        }

        # instantiate a module
        {
            no strict 'refs';
            ${ $package_name . '::VERSION'   } = delete $options{version}   if exists $options{version};
            ${ $package_name . '::AUTHORITY' } = delete $options{authority} if exists $options{authority};
        }

        my $meta = $self->initialize( $package_name, %options);

        weaken $METAS{$package_name}
            if $mortal;

        $meta->add_method(meta => sub{
            $self->initialize(ref($_[0]) || $_[0]);
        });

        $meta->superclasses(@{$superclasses})
            if defined $superclasses;

        # NOTE:
        # process attributes first, so that they can
        # install accessors, but locally defined methods
        # can then overwrite them. It is maybe a little odd, but
        # I think this should be the order of things.
        if (defined $attributes) {
            if(ref($attributes) eq 'ARRAY'){
                # array of Mouse::Meta::Attribute
                foreach my $attr (@{$attributes}) {
                    $meta->add_attribute($attr);
                }
            }
            else{
                # hash map of name and attribute spec pairs
                while(my($name, $attr) = each %{$attributes}){
                    $meta->add_attribute($name => $attr);
                }
            }
        }
        if (defined $methods) {
            while(my($method_name, $method_body) = each %{$methods}){
                $meta->add_method($method_name, $method_body);
            }
        }
        if (defined $roles){
            Mouse::Util::apply_all_roles($package_name, @{$roles});
        }

        if($cache_key){
            $IMMORTALS{$cache_key} = $meta;
        }

        return $meta;
    }

    sub DESTROY{
        my($self) = @_;

        my $serial_id = $self->{anon_serial_id};

        return if !$serial_id;

        # @ISA is a magical variable, so we clear it manually.
        @{$self->{superclasses}} = () if exists $self->{superclasses};

        # Then, clear the symbol table hash
        %{$self->namespace} = ();

        my $name = $self->name;
        delete $METAS{$name};

        $name =~ s/ $serial_id \z//xms;

        no strict 'refs';
        delete ${$name}{ $serial_id . '::' };

        return;
    }
}

sub throw_error{
    my($class, $message, %args) = @_;

    local $Carp::CarpLevel  = $Carp::CarpLevel + 1 + ($args{depth} || 0);
    local $Carp::MaxArgNums = 20; # default is 8, usually we use named args which gets messier though

    if(exists $args{longmess} && !$args{longmess}){ # intentionaly longmess => 0
        Carp::croak($message);
    }
    else{
        Carp::confess($message);
    }
}

1;

__END__

=head1 NAME

Mouse::Meta::Module - The base class for Mouse::Meta::Class and Mouse::Meta::Role

=head1 VERSION

This document describes Mouse version 0.40

=head1 SEE ALSO

L<Class::MOP::Class>

L<Class::MOP::Module>

L<Class::MOP::Package>

=cut

