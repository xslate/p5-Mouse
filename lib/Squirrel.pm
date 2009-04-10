package Squirrel;
use strict;
use warnings;

sub _choose_backend {
    if ( $INC{"Moose.pm"} ) {
        return {
            import   => \&Moose::import,
            unimport => \&Moose::unimport,
        }
    } else {
        require Mouse;
        return {
            import   => \&Mouse::import,
            unimport => \&Mouse::unimport,
        }
    }
}

my %pkgs;

sub _handlers {
    my $class = shift;

    my $caller = caller(1);

    $pkgs{$caller} = $class->_choose_backend
        unless $pkgs{$caller};
}

sub import {
    require Carp;
    Carp::carp("Squirrel is deprecated. Please use Any::Moose instead. It fixes a number of design problems that Squirrel has.");
    goto $_[0]->_handlers->{import};
}

sub unimport {
    goto $_[0]->_handlers->{unimport};
}

1;

__END__

=pod

=head1 NAME

Squirrel - Use L<Mouse>, unless L<Moose> is already loaded.

=head1 SYNOPSIS

	use Squirrel;

    has goggles => (
        is => "rw", 
    );

=head1 DEPRECATION

L<Squirrel> is being deprecated. L<Any::Moose> provides the same functionality,
but better. :)

=head1 DESCRIPTION

L<Moose> and L<Squirrel> are TEH BEST FRENDS, but if L<Moose> isn't there
L<Squirrel> will hang out with L<Mouse> as well.

When your own code doesn't actually care whether or not you use L<Moose> or
L<Mouse> you can use either, and let your users decide for you.

This lets you run with minimal dependencies and have a faster startup, but if
L<Moose> is already in use you get all the benefits of using that
(transformability, introspection, more opportunities for code reuse, etc).

=cut


