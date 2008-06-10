#!perl
package Mouse;
use strict;
use warnings;

our $VERSION = '0.01';

use Sub::Exporter;
use Carp 'confess';
use Scalar::Util 'blessed';

use Mouse::Attribute;
use Mouse::Class;
use Mouse::Object;
use Mouse::TypeRegistry;

do {
    my $CALLER;

    my %exports = (
        meta => sub {
            my $meta = Mouse::Class->initialize($CALLER);
            return sub { $meta };
        },

        extends => sub {
            my $caller = $CALLER;
            return sub {
                $caller->meta->superclasses(@_);
            };
        },

        has => sub {
            return sub {
                my $package = caller;
                my $names = shift;
                $names = [$names] if !ref($names);

                for my $name (@$names) {
                    Mouse::Attribute->create($package, $name, @_);
                }
            };
        },

        confess => sub {
            return \&confess;
        },

        blessed => sub {
            return \&blessed;
        },
    );

    my $exporter = Sub::Exporter::build_exporter({
        exports => \%exports,
        groups  => { default => [':all'] },
    });

    sub import {
        $CALLER = caller;

        strict->import;
        warnings->import;

        my $meta = Mouse::Class->initialize($CALLER);
        $meta->superclasses('Mouse::Object')
            unless $meta->superclasses;

        goto $exporter;
    }

    sub unimport {
        my $caller = caller;

        no strict 'refs';
        for my $keyword (keys %exports) {
            next if $keyword eq 'meta'; # we don't delete this one
            delete ${ $caller . '::' }{$keyword};
        }
    }
};

sub load_class {
    my $class = shift;

    (my $file = "$class.pm") =~ s{::}{/}g;

    eval { CORE::require($file) };
    confess "Could not load class ($class) because : $@"
        if $@
        && $@ !~ /^Can't locate .*? at /;

    return 1;
}

1;

__END__

=head1 NAME

Mouse - Moose minus antlers

=head1 VERSION

Version 0.01 released ???

=head1 SYNOPSIS

    package Point;
    use Mouse; # automatically turns on strict and warnings

    has 'x' => (is => 'rw', isa => 'Int');
    has 'y' => (is => 'rw', isa => 'Int');

    sub clear {
        my $self = shift;
        $self->x(0);
        $self->y(0);
    }

    package Point3D;
    use Mouse;

    extends 'Point';

    has 'z' => (is => 'rw', isa => 'Int');

    #after 'clear' => sub {
    #    my $self = shift;
    #    $self->z(0);
    #};

=head1 DESCRIPTION

Moose.

=head1 INTERFACE

=head2 meta -> Mouse::Class

Returns this class' metaclass instance.

=head2 extends superclasses

Sets this class' superclasses.

=head2 has (name|names) => parameters

Adds an attribute (or if passed an arrayref of names, multiple attributes) to
this class.

=head2 confess error -> BOOM

L<Carp/confess> for your convenience.

=head2 blessed value -> ClassName | undef

L<Scalar::Util/blessed> for your convenience.

=head1 MISC

=head2 import

Importing Mouse will default your class' superclass list to L<Mouse::Object>.
You may use L</extends> to replace the superclass list.

=head2 unimport

Please unimport Mouse so that if someone calls one of the keywords (such as
L</extends>) it will break loudly instead breaking subtly.

=head1 FUNCTIONS

=head2 load_class Class::Name

This will load a given C<Class::Name> (or die if it's not loadable).
This function can be used in place of tricks like
C<eval "use $module"> or using C<require>.

=head1 AUTHOR

Shawn M Moore, C<< <sartak at gmail.com> >>

=head1 BUGS

No known bugs.

Please report any bugs through RT: email
C<bug-mouse at rt.cpan.org>, or browse
L<http://rt.cpan.org/NoAuth/ReportBug.html?Queue=Mouse>.

=head1 COPYRIGHT AND LICENSE

Copyright 2008 Shawn M Moore.

This program is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.

=cut

