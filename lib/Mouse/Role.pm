#!/usr/bin/env perl
package Mouse::Role;
use strict;
use warnings;

use Sub::Exporter;
use Carp 'confess';
use Scalar::Util;

use Mouse::Meta::Role;

do {
    my $CALLER;

    my %exports = (
        meta => sub {
            my $meta = Mouse::Meta::Role->initialize($CALLER);
            return sub { $meta };
        },
        extends => sub {
            return sub {
                confess "Role does not currently support 'extends'";
            }
        },
        before => sub {
            return sub { }
        },
        after => sub {
            return sub { }
        },
        around => sub {
            return sub { }
        },
        has => sub {
            my $caller = $CALLER;
            return sub {
                my $name = shift;
                my %opts = @_;

                $caller->meta->add_attribute($name => \%opts);
            }
        },
        with => sub {
            return sub {
                confess "Role does not currently support 'with'";
            }
        },
        requires => sub {
            return sub { }
        },
        excludes => sub {
            return sub { }
        },
        blessed => sub {
            return \&Scalar::Util::blessed;
        },
        confess => sub {
            return \&Carp::confess;
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

1;

__END__

=head1 NAME

Mouse::Role

=head1 KEYWORDS

=head2 meta -> Mouse::Meta::Role

Returns this role's metaclass instance.

=head2 before (method|methods) => Code

Sets up a "before" method modifier. See L<Moose/before> or
L<Class::Method::Modifiers/before>.

=head2 after (method|methods) => Code

Sets up an "after" method modifier. See L<Moose/after> or
L<Class::Method::Modifiers/after>.

=head2 around (method|methods) => Code

Sets up an "around" method modifier. See L<Moose/around> or
L<Class::Method::Modifiers/around>.

=head2 has (name|names) => parameters

Sets up an attribute (or if passed an arrayref of names, multiple attributes) to
this role. See L<Mouse/has>.

=head2 confess error -> BOOM

L<Carp/confess> for your convenience.

=head2 blessed value -> ClassName | undef

L<Scalar::Util/blessed> for your convenience.

=head1 MISC

=head2 import

Importing Mouse::Role will give you sugar.

=head2 unimport

Please unimport Mouse (C<no Mouse::Role>) so that if someone calls one of the
keywords (such as L</has>) it will break loudly instead breaking subtly.

=cut

