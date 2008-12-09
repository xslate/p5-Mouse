package Squirrel::Role;
use strict;
use warnings;

sub _choose_backend {
    if ( $INC{"Moose/Role.pm"} ) {
        return {
            import   => \&Moose::Role::import,
            unimport => defined &Moose::Role::unimport ? \&Moose::Role::unimport : sub {},
        }
    } else {
        require Mouse::Role;
        return {
            import   => \&Mouse::Role::import,
            unimport => \&Mouse::Role::unimport,
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
    goto $_[0]->_handlers->{import};
}

sub unimport {
    goto $_[0]->_handlers->{unimport};
}

1;

