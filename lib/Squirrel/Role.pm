package Squirrel::Role;
use strict;
use warnings;

use base qw(Squirrel);

sub _choose_backend {
    if ( $INC{"Moose/Role.pm"} ) {
        return {
            backend  => 'Moose::Role',
            import   => \&Moose::Role::import,
            unimport => \&Moose::Role::unimport,
        }
    }
    else {
        require Mouse::Role;
        return {
            backend  => 'Mouse::Role',
            import   => \&Mouse::Role::import,
            unimport => \&Mouse::Role::unimport,
        }
    }
}

1;

__END__

=head1 NAME

Squirrel::Role - Use Mouse::Role, unless Moose::Role is already loaded. (DEPRECATED)

=head1 SYNOPSIS

    use Squirrel::Role;

=head1 DEPRECATION

C<Squirrel::Role> is deprecated. C<Any::Moose> provides the same functionality,
but better. :)

=head1 SEE ALSO

L<Any::Moose>

=cut

