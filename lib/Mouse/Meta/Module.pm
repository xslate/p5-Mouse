package Mouse::Meta::Module;
use strict;
use warnings;

use Mouse::Util qw/get_code_info not_supported load_class/;
use Scalar::Util qw/blessed weaken/;


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

    sub Mouse::class_of{
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
