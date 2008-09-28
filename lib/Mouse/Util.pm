#!/usr/bin/env perl
package Mouse::Util;
use strict;
use warnings;
use base 'Exporter';

our %dependencies = (
    'MRO::Compat' => {
        'get_linear_isa' => {
            loaded     => \&mro::get_linear_isa,
            not_loaded => do {
                # this recurses so it isn't pretty
                my $code;
                $code = sub {
                    no strict 'refs';

                    my $classname = shift;

                    my @lin = ($classname);
                    my %stored;
                    foreach my $parent (@{"$classname\::ISA"}) {
                        my $plin = $code->($parent);
                        foreach (@$plin) {
                            next if exists $stored{$_};
                            push(@lin, $_);
                            $stored{$_} = 1;
                        }
                    }
                    return \@lin;
                }
            },
        },
    },
);

our @EXPORT_OK = map { keys %$_ } values %dependencies;

for my $module_name (keys %dependencies) {
    (my $file = "$module_name.pm") =~ s{::}{/}g;

    my $loaded = do {
        local $SIG{__DIE__} = 'DEFAULT';
        eval "require '$file'; 1";
    };

    for my $method_name (keys %{ $dependencies{ $module_name } }) {
        my $producer = $dependencies{$module_name}{$method_name};
        my $implementation;

        if (ref($producer) eq 'HASH') {
            $implementation = $loaded
                            ? $producer->{loaded}
                            : $producer->{not_loaded};
        }
        else {
            $implementation = $loaded
                            ? $module_name->can($method_name)
                            : $producer;
        }

        no strict 'refs';
        *{ __PACKAGE__ . '::' . $method_name } = $implementation;
    }
}

1;

