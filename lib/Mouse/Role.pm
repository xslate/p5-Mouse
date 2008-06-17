#!/usr/bin/env perl
package Mouse::Role;
use strict;
use warnings;

use Sub::Exporter;

do {
    my $CALLER;

    my %exports = (
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

