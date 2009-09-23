package Mouse::Meta::Module;
use strict;
use warnings;

use Carp ();
use Scalar::Util qw/blessed weaken/;

use Mouse::Util qw/get_code_info not_supported load_class/;

{
    my %METACLASS_CACHE;

    # because Mouse doesn't introspect existing classes, we're forced to
    # only pay attention to other Mouse classes
    sub _metaclass_cache {
        my($class, $name) = @_;
        return $METACLASS_CACHE{$name};
    }

    sub initialize {
        my($class, $package_name, @args) = @_;

        ($package_name && !ref($package_name))
            || $class->throw_error("You must pass a package name and it cannot be blessed");

        return $METACLASS_CACHE{$package_name}
            ||= $class->_new(package => $package_name, @args);
    }

    sub class_of{
        my($class_or_instance) = @_;
        return undef unless defined $class_or_instance;
        return $METACLASS_CACHE{ blessed($class_or_instance) || $class_or_instance };
    }

    # Means of accessing all the metaclasses that have
    # been initialized thus far
    sub get_all_metaclasses         {        %METACLASS_CACHE         }
    sub get_all_metaclass_instances { values %METACLASS_CACHE         }
    sub get_all_metaclass_names     { keys   %METACLASS_CACHE         }
    sub get_metaclass_by_name       { $METACLASS_CACHE{$_[0]}         }
    sub store_metaclass_by_name     { $METACLASS_CACHE{$_[0]} = $_[1] }
    sub weaken_metaclass            { weaken($METACLASS_CACHE{$_[0]}) }
    sub does_metaclass_exist        { defined $METACLASS_CACHE{$_[0]} }
    sub remove_metaclass_by_name    { delete $METACLASS_CACHE{$_[0]}  }

}

sub meta{ Mouse::Meta::Class->initialize(ref $_[0] || $_[0]) }

sub _new{ Carp::croak("Mouse::Meta::Module is an abstract class") }

sub name { $_[0]->{package} }
sub _method_map{ $_[0]->{methods} }

sub version   { no strict 'refs'; ${shift->name.'::VERSION'}   }
sub authority { no strict 'refs'; ${shift->name.'::AUTHORITY'} }
sub identifier {
    my $self = shift;
    return join '-' => (
        $self->name,
        ($self->version   || ()),
        ($self->authority || ()),
    );
}

# add_attribute is an abstract method

sub get_attribute_map {        $_[0]->{attributes}          }
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
        $self->throw_error("You must pass a defined name");
    }
    if(ref($code) ne 'CODE'){
        not_supported 'add_method for a method object';
    }

    $self->_method_map->{$name}++; # Moose stores meta object here.

    my $pkg = $self->name;
    no strict 'refs';
    no warnings 'redefine';
    *{ $pkg . '::' . $name } = $code;
}

sub _code_is_mine { # taken from Class::MOP::Class
    my ( $self, $code ) = @_;

    my ( $code_package, $code_name ) = get_code_info($code);

    return $code_package && $code_package eq $self->name
        || ( $code_package eq 'constant' && $code_name eq '__ANON__' );
}

sub has_method {
    my($self, $method_name) = @_;

    return 1 if $self->_method_map->{$method_name};
    my $code = $self->name->can($method_name);

    return $code && $self->_code_is_mine($code);
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
    my $ANON_PREFIX = 'Mouse::Meta::Module::__ANON__::';

    my %IMMORTALS;

    sub create {
        my ($class, $package_name, %options) = @_;

        $class->throw_error('You must pass a package name') if @_ == 1;


        if(exists $options{superclasses}){
            if($class->isa('Mouse::Meta::Class')){
                (ref $options{superclasses} eq 'ARRAY')
                    || $class->throw_error("You must pass an ARRAY ref of superclasses");
            }
            else{ # role
                delete $options{superclasses};
            }
        }

        my $attributes;
        if(exists $options{attributes}){
            $attributes = delete $options{attributes};
           (ref $attributes eq 'ARRAY' || ref $attributes eq 'HASH')
               || $class->throw_error("You must pass an ARRAY ref of attributes")
           }

        (ref $options{methods} eq 'HASH')
            || $class->throw_error("You must pass a HASH ref of methods")
                if exists $options{methods};

        (ref $options{roles} eq 'ARRAY')
            || $class->throw_error("You must pass an ARRAY ref of roles")
                if exists $options{roles};


        my @extra_options;
        my $mortal;
        my $cache_key;

        if(!defined $package_name){ # anonymous
            $mortal = !$options{cache};

            # anonymous but immortal
            if(!$mortal){
                    # something like Super::Class|Super::Class::2=Role|Role::1
                    $cache_key = join '=' => (
                        join('|',      @{$options{superclasses} || []}),
                        join('|', sort @{$options{roles}        || []}),
                    );
                    return $IMMORTALS{$cache_key} if exists $IMMORTALS{$cache_key};
            }
            $package_name = $ANON_PREFIX . ++$ANON_SERIAL;

            push @extra_options, (anon_serial_id => $ANON_SERIAL);
        }

        # instantiate a module
        {
            no strict 'refs';
            ${ $package_name . '::VERSION'   } = delete $options{version}   if exists $options{version};
            ${ $package_name . '::AUTHORITY' } = delete $options{authority} if exists $options{authority};
        }

        my %initialize_options = %options;
        delete @initialize_options{qw(
            package
            superclasses
            attributes
            methods
            roles
        )};
        my $meta = $class->initialize( $package_name, %initialize_options, @extra_options);

        Mouse::Meta::Module::weaken_metaclass($package_name)
            if $mortal;

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
        if (defined $attributes) {
            if(ref($attributes) eq 'ARRAY'){
                foreach my $attr (@{$attributes}) {
                    $meta->add_attribute($attr->{name} => $attr);
                }
            }
            else{
                while(my($name, $attr) = each %{$attributes}){
                    $meta->add_attribute($name => $attr);
                }
            }
        }
        if (exists $options{methods}) {
            foreach my $method_name (keys %{$options{methods}}) {
                $meta->add_method($method_name, $options{methods}->{$method_name});
            }
        }
        if (exists $options{roles}){
            Mouse::Util::apply_all_roles($package_name, @{$options{roles}});
        }

        if(!$mortal && exists $meta->{anon_serial_id}){
            $IMMORTALS{$cache_key} = $meta;
        }

        return $meta;
    }

    sub DESTROY{
        my($self) = @_;

        my $serial_id = $self->{anon_serial_id};

        return if !$serial_id;

        my $stash = $self->namespace;

        @{$self->{superclasses}} = () if exists $self->{superclasses};
        %{$stash} = ();
        Mouse::Meta::Module::remove_metaclass_by_name($self->name);

        no strict 'refs';
        delete ${$ANON_PREFIX}{ $serial_id . '::' };

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

Mouse::Meta::Module - Common base class for Mouse::Meta::Class and Mouse::Meta::Role

=cut
