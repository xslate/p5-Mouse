package Mouse::Meta::Module;
use strict;
use warnings;

use Mouse::Util qw/get_code_info/;
use Carp 'confess';

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


sub namespace{
    my $name = $_[0]->{package};
    no strict 'refs';
    return \%{ $name . '::' };
}

sub add_method {
    my($self, $name, $code) = @_;

    if(!defined $name){
        confess "You must pass a defined name";
    }
    if(ref($code) ne 'CODE'){
        confess "You must pass a CODE reference";
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



sub get_method_list {
    my($self) = @_;

    return grep { $self->has_method($_) } keys %{ $self->namespace };
}

sub get_attribute_map { $_[0]->{attributes} }
sub has_attribute     { exists $_[0]->{attributes}->{$_[1]} }
sub get_attribute     { $_[0]->{attributes}->{$_[1]} }
sub get_attribute_list {
    my $self = shift;
    keys %{$self->get_attribute_map};
}


1;

__END__

=head1 NAME

Mouse::Meta::Module - Common base class for Mouse::Meta::Class and Mouse::Meta::Role

=cut
