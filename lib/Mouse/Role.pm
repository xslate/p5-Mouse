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
            return sub { }
        },
        with => sub {
            return sub { }
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
    }
};

1;

