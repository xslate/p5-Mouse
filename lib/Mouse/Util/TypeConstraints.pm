package Mouse::Util::TypeConstraints;
use strict;
use warnings;

use Carp ();
use Scalar::Util qw/blessed looks_like_number openhandle/;

my %TYPE;
my %TYPE_SOURCE;
my %COERCE;
my %COERCE_KEYS;

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
    *{"$caller\::type"}        = \&_type;
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

my $optimized_constraints;
my $optimized_constraints_base;
{
    no warnings 'uninitialized';
    %TYPE = (
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
            ref($_) eq 'GLOB' && openhandle($_)
            or
            blessed($_) && $_->isa("IO::Handle")
        },

        Object     => sub { blessed($_) && blessed($_) ne 'Regexp' },
    );

    sub optimized_constraints { \%TYPE }
    my @TYPE_KEYS = keys %TYPE;
    sub list_all_builtin_type_constraints { @TYPE_KEYS }

    @TYPE_SOURCE{@TYPE_KEYS} = (__PACKAGE__) x @TYPE_KEYS;
}

sub _type {
    my $pkg = caller(0);
    my($name, %conf) = @_;
    if ($TYPE{$name} && $TYPE_SOURCE{$name} ne $pkg) {
        Carp::croak "The type constraint '$name' has already been created in $TYPE_SOURCE{$name} and cannot be created again in $pkg";
    };
    my $constraint = $conf{where} || do { $TYPE{delete $conf{as} || 'Any' } };

    $TYPE_SOURCE{$name} = $pkg;
    $TYPE{$name} = $constraint;
}

sub _subtype {
    my $pkg = caller(0);
    my($name, %conf) = @_;
    if ($TYPE{$name} && $TYPE_SOURCE{$name} ne $pkg) {
        Carp::croak "The type constraint '$name' has already been created in $TYPE_SOURCE{$name} and cannot be created again in $pkg";
    };
    my $constraint = $conf{where} || do { $TYPE{delete $conf{as} || 'Any' } };
    my $as         = $conf{as} || '';

    $TYPE_SOURCE{$name} = $pkg;

    if ($as = $TYPE{$as}) {
        $TYPE{$name} = sub { $as->($_) && $constraint->($_) };
    } else {
        $TYPE{$name} = $constraint;
    }
}

sub _coerce {
    my($name, %conf) = @_;

    Carp::croak "Cannot find type '$name', perhaps you forgot to load it."
        unless $TYPE{$name};

    unless ($COERCE{$name}) {
        $COERCE{$name}      = {};
        $COERCE_KEYS{$name} = [];
    }
    while (my($type, $code) = each %conf) {
        Carp::croak "A coercion action already exists for '$type'"
            if $COERCE{$name}->{$type};

        Carp::croak "Could not find the type constraint ($type) to coerce from"
            unless $TYPE{$type};

        push @{ $COERCE_KEYS{$name} }, $type;
        $COERCE{$name}->{$type} = $code;
    }
}

sub _class_type {
    my $pkg = caller(0);
    my($name, $conf) = @_;
    my $class = $conf->{class};
    _subtype(
        $name => where => sub { $_->isa($class) }
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
    my($class, $pkg, $type_constraint, $types, $value) = @_;

    local $_;
    for my $type (ref($types) eq 'ARRAY' ? @{ $types } : ( $types )) {
        next unless $COERCE{$type};
        for my $coerce_type (@{ $COERCE_KEYS{$type}}) {
            $_ = $value;
            next unless $TYPE{$coerce_type}->();
            $_ = $value;
            $_ = $COERCE{$type}->{$coerce_type}->();
            return $_ if $type_constraint->();
        }
    }
    return $value;
}

1;

__END__

=head1 NAME

Mouse::Util::TypeConstraints - simple type constraints

=head1 METHODS

=head2 optimized_constraints -> HashRef[CODE]

Returns the simple type constraints that Mouse understands.

=cut


