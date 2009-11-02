package Mouse::Meta::Role::Method;
use Mouse::Util; # enables strict and warnings

use Mouse::Meta::Method;
our @ISA = qw(Mouse::Meta::Method);

sub _new {
    my $class = shift;
    return $class->meta->new_object(@_)
        if $class ne __PACKAGE__;
    return bless {@_}, $class;
}

1;
__END__

=head1 NAME

Mouse::Meta::Role::Method - A Mouse Method metaclass for Roles

=head1 VERSION

This document describes Mouse version 0.40_05

=head1 SEE ALSO

L<Moose::Meta::Role::Method>

=cut

