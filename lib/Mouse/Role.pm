#!/usr/bin/env perl
package Mouse::Role;
use strict;
use warnings;

use Sub::Exporter;
use Carp 'confess';

do {
    my $CALLER;

    my %exports = (
        extends => sub {
            return sub {
                confess "Mouse::Role does not currently support 'extends'";
            }
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

