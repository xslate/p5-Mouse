#!/usr/bin/env perl
package Mouse::TypeRegistry;
use strict;
use warnings;

use Carp ();
use Mouse::Util qw/blessed looks_like_number openhandle/;

my $SUBTYPE = +{};
my $COERCE = +{};

#find_type_constraint register_type_constraint
sub import {
    my $class  = shift;
    my %args   = @_;
    my $caller = $args{callee} || caller(0);

    no strict 'refs';
    *{"$caller\::as"}          = \&_as;
    *{"$caller\::where"}       = \&_where;
    *{"$caller\::message"}     = \&_message;
    *{"$caller\::from"}        = \&_from;
    *{"$caller\::via"}         = \&_via;
    *{"$caller\::subtype"}     = \&_subtype;
    *{"$caller\::coerce"}      = \&_coerce;
    *{"$caller\::class_type"}  = \&_class_type;
    *{"$caller\::role_type"}   = \&_role_type;
}


sub _as ($) {
    as => $_[0]
}
sub _where (&) {
    where => $_[0]
}
sub _message ($) {
    message => $_[0]
}

sub _from { @_ }
sub _via (&) {
    $_[0]
}

sub _subtype {
    my $pkg = caller(0);
    my($name, %conf) = @_;
    if (my $type = $SUBTYPE->{$name}) {
        Carp::croak "The type constraint '$name' has already been created, cannot be created again in $pkg";
    };
    my $as = $conf{as};
    my $stuff = $conf{where} || optimized_constraints()->{$as};

    $SUBTYPE->{$name} = $stuff;
}

sub _coerce {
    my($name, %conf) = @_;

    Carp::croak "Cannot find type '$name', perhaps you forgot to load it."
        unless optimized_constraints()->{$name};

    my $subtypes = optimized_constraints();
    $COERCE->{$name} ||= {};
    while (my($type, $code) = each %conf) {
        Carp::croak "A coercion action already exists for '$type'"
            if $COERCE->{$name}->{$type};

        Carp::croak "Could not find the type constraint ($type) to coerce from"
            unless $subtypes->{$type};

        $COERCE->{$name}->{$type} = $code;
    }
}

sub _class_type {
    my $pkg = caller(0);
    my($name, $conf) = @_;
    my $class = $conf->{class};
    _subtype(
        $name => where => sub {
            defined $_ && ref($_) eq $class;
        }
    );
}

sub _role_type {
    my($name, $conf) = @_;
    my $role = $conf->{role};
    _subtype(
        $name => where => sub {
            return unless defined $_ && ref($_) && $_->isa('Mouse::Object');
            $_->meta->does_role($role);
        }
    );
}

sub typecast_constraints {
    my($class, $pkg, $type, $value) = @_;
    return $value unless $COERCE->{$type};

    my $optimized_constraints = optimized_constraints();
    for my $coerce_type (keys %{ $COERCE->{$type} }) {
        local $_ = $value;
        if ($optimized_constraints->{$coerce_type}->()) {
            local $_ = $value;
            return $COERCE->{$type}->{$coerce_type}->();
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
        return { %{ $SUBTYPE }, %{ $optimized_constraints } };
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


