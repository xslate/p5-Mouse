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
        ClassName  => sub { Mouse::is_class_loaded($_) },
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
    };
}

1;

__END__

=head1 NAME

Mouse::TypeRegistry - simple type constraints

=head1 METHODS

=head2 optimized_constraints -> HashRef[CODE]

Returns the simple type constraints that Mouse understands.

=cut


