package Mouse::Meta::Method;
use Mouse::Util qw(:meta); # enables strict and warnings

use overload
    '&{}' => 'body',
    fallback => 1,
;

sub new{
    my($class, %args) = @_;

    return bless \%args, $class;
}

sub body        { $_[0]->{body}    }
sub name        { $_[0]->{name}    }
sub package_name{ $_[0]->{package} }

sub fully_qualified_name {
    my $self = shift;
    return $self->package_name . '::' . $self->name;
}

1;

__END__

=head1 NAME

Mouse::Meta::Method - A Mouse Method metaclass

=head1 VERSION

This document describes Mouse version 0.40

=head1 SEE ALSO

L<Moose::Meta::Method>

L<Class::MOP::Method>

=cut
