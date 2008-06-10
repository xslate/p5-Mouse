#!/usr/bin/env perl
package Mouse::TypeRegistry;
use strict;
use warnings;
use Scalar::Util qw/looks_like_number blessed openhandle/;

no warnings 'uninitialized';
sub optimized_constraints {
    return {
        Any        => sub { 1 },
        Item       => sub { 1 },
        Bool       => sub {
            !defined($_) || $_ eq "" || "$_" eq '1' || "$_" eq '0'
        },
        Undef      => sub { !defined($_) },
        Defined    => sub { defined($_) },
        Value      => sub { defined($_) && !ref($_) },
        Num        => sub { !ref($_) && looks_like_number($_) },
        Int        => sub { defined($_) && !ref($_) && /^-?[0-9]+$/ },
        Str        => sub { defined($_) && !ref($_) },
        Ref        => sub { ref($_) },

        ScalarRef  => sub { ref($_) eq 'SCALAR' },
        ArrayRef   => sub { ref($_) eq 'ARRAY'  },
        HashRef    => sub { ref($_) eq 'HASH'   },
        CodeRef    => sub { ref($_) eq 'CODE'   },
        RegexpRef  => sub { ref($_) eq 'Regexp' },
        GlobRef    => sub { ref($_) eq 'GLOB'   },

        FileHandle => sub {
                ref($_) eq 'GLOB'
                && openhandle($_)
            or
                blessed($_)
                && $_->isa("IO::Handle")
        },

        Object     => sub { blessed($_) && blessed($_) ne 'Regexp' },

        ClassName  => sub {
            return if ref($_);
            return unless defined($_) && length($_);

            # walk the symbol table tree to avoid autovififying
            # \*{${main::}{"Foo::"}} == \*main::Foo::

            my $pack = \*::;
            foreach my $part (split('::', $_)) {
                return unless exists ${$$pack}{"${part}::"};
                $pack = \*{${$$pack}{"${part}::"}};
            }

            # check for $VERSION or @ISA
            return 1 if exists ${$$pack}{VERSION}
                    && defined *{${$$pack}{VERSION}}{SCALAR};
            return 1 if exists ${$$pack}{ISA}
                    && defined *{${$$pack}{ISA}}{ARRAY};

            # check for any method
            foreach ( keys %{$$pack} ) {
                next if substr($_, -2, 2) eq '::';
                return 1 if defined *{${$$pack}{$_}}{CODE};
            }

            # fail
            return;
        },
    };
}

1;

