package Mouse::Meta::Method;
use Mouse::Util qw(:meta); # enables strict and warnings

use overload
    '&{}' => sub{ $_[0]->body },
    fallback => 1,
;

sub wrap{
    my $class = shift;

    return $class->_new(@_);
}

sub _new{
    my $class = shift;
    return $class->meta->new_object(@_)
        if $class ne __PACKAGE__;

    return bless {@_}, $class;
}

sub body                 { $_[0]->{body}    }
sub name                 { $_[0]->{name}    }
sub package_name         { $_[0]->{package} }
sub associated_metaclass { $_[0]->{associated_metaclass} }

sub fully_qualified_name {
    my $self = shift;
    return $self->package_name . '::' . $self->name;
}

1;
__END__

=head1 NAME

Mouse::Meta::Method - A Mouse Method metaclass

=head1 VERSION

This document describes Mouse version 0.40_08

=head1 SEE ALSO

L<Moose::Meta::Method>

L<Class::MOP::Method>

=cut
