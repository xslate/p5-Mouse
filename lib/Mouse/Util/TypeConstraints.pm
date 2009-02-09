package Mouse::Util::TypeConstraints;
use strict;
use warnings;
use base 'Exporter';

use Carp ();
use Scalar::Util qw/blessed looks_like_number openhandle/;

our @EXPORT = qw(
    as where message from via type subtype coerce class_type role_type enum
);

my %TYPE;
my %TYPE_SOURCE;
my %COERCE;
my %COERCE_KEYS;

sub as ($) {
    as => $_[0]
}
sub where (&) {
    where => $_[0]
}
sub message (&) {
    message => $_[0]
}

sub from { @_ }
sub via (&) {
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

sub type {
    my $pkg = caller(0);
    my($name, %conf) = @_;
    if ($TYPE{$name} && $TYPE_SOURCE{$name} ne $pkg) {
        Carp::croak "The type constraint '$name' has already been created in $TYPE_SOURCE{$name} and cannot be created again in $pkg";
    };
    my $constraint = $conf{where} || do { $TYPE{delete $conf{as} || 'Any' } };

    $TYPE_SOURCE{$name} = $pkg;
    $TYPE{$name} = $constraint;
}

sub subtype {
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

sub coerce {
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

sub class_type {
    my $pkg = caller(0);
    my($name, $conf) = @_;
    my $class = $conf->{class};
    subtype(
        $name => where => sub { $_->isa($class) }
    );
}

sub role_type {
    my($name, $conf) = @_;
    my $role = $conf->{role};
    subtype(
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

my $serial_enum = 0;
sub enum {
    # enum ['small', 'medium', 'large']
    if (ref($_[0]) eq 'ARRAY') {
        my @elements = @{ shift @_ };

        my $name = 'Mouse::Util::TypeConstaints::Enum::Serial::'
                 . ++$serial_enum;
        enum($name, @elements);
        return $name;
    }

    # enum size => 'small', 'medium', 'large'
    my $name = shift;
    my %is_valid = map { $_ => 1 } @_;

    subtype(
        $name => where => sub { $is_valid{$_} }
    );
}

1;

__END__

=head1 NAME

Mouse::Util::TypeConstraints - simple type constraints

=head1 METHODS

=head2 optimized_constraints -> HashRef[CODE]

Returns the simple type constraints that Mouse understands.

=cut


