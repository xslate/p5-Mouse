#!/usr/bin/env perl
package Mouse::TypeRegistry;
use strict;
use warnings;

use Mouse::Util qw/blessed looks_like_number openhandle/;

my $SUBTYPE = +{};
my $COERCE = +{};

sub import {
    my $class  = shift;
    my %args   = @_;
    my $caller = caller(0);

    $SUBTYPE->{$caller} ||= +{};
    $COERCE->{$caller}  ||= +{};

    if (defined $args{'-export'} && ref($args{'-export'}) eq 'ARRAY') {
        no strict 'refs';
        *{"$caller\::import"} = sub { _import(@_) };
    }

    no strict 'refs';
    *{"$caller\::subtype"}     = \&_subtype;
    *{"$caller\::coerce"}      = \&_coerce;
    *{"$caller\::class_type"}  = \&_class_type;
    *{"$caller\::role_type"}   = \&_role_type;
}

sub _import {
    my($class, @types) = @_;
    return unless exists $SUBTYPE->{$class} && exists $COERCE->{$class};
    my $pkg = caller(1);
    return unless @types;
    copy_types($class, $pkg, @types);
}

sub _subtype {
    my $pkg = caller(0);
    my($name, $stuff) = @_;
    if (ref $stuff eq 'HASH') {
        my $as = $stuff->{as};
        $stuff = optimized_constraints()->{$as};
    }
    $SUBTYPE->{$pkg}->{$name} = $stuff;
}

sub _coerce {
    my $pkg = caller(0);
    my($name, $conf) = @_;
    $COERCE->{$pkg}->{$name} = $conf;
}

sub _class_type {
    my $pkg = caller(0);
    $SUBTYPE->{$pkg} ||= +{};
    my($name, $conf) = @_;
    my $class = $conf->{class};
    $SUBTYPE->{$pkg}->{$name} = sub {
        defined $_ && ref($_) eq $class;
    };
}

sub _role_type {
    my $pkg = caller(0);
    $SUBTYPE->{$pkg} ||= +{};
    my($name, $conf) = @_;
    my $role = $conf->{role};
    $SUBTYPE->{$pkg}->{$name} = sub {
        return unless defined $_ && ref($_) && $_->isa('Mouse::Object');
        $_->meta->does_role($role);
    };
}

sub typecast_constraints {
    my($class, $pkg, $type, $value) = @_;
    return $value unless defined $COERCE->{$pkg} && defined $COERCE->{$pkg}->{$type};

    my $optimized_constraints = optimized_constraints();
    for my $coerce_type (keys %{ $COERCE->{$pkg}->{$type} }) {
        local $_ = $value;
        if ($optimized_constraints->{$coerce_type}->()) {
            local $_ = $value;
            return $COERCE->{$pkg}->{$type}->{$coerce_type}->();
        }
    }

    return $value;
}

{
    no warnings 'uninitialized';
    my $optimized_constraints = {
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
    sub optimized_constraints {
        my($class, $pkg) = @_;
        my $subtypes = $SUBTYPE->{$pkg} || {};
        return { %{ $subtypes }, %{ $optimized_constraints } };
    }
}

1;

__END__

=head1 NAME

Mouse::TypeRegistry - simple type constraints

=head1 METHODS

=head2 optimized_constraints -> HashRef[CODE]

Returns the simple type constraints that Mouse understands.

=cut


