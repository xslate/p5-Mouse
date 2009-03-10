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
            !defined($_[0]) || $_[0] eq "" || "$_[0]" eq '1' || "$_[0]" eq '0'
        },
        Undef      => sub { !defined($_[0]) },
        Defined    => sub { defined($_[0]) },
        Value      => sub { defined($_[0]) && !ref($_[0]) },
        Num        => sub { !ref($_[0]) && looks_like_number($_[0]) },
        Int        => sub { defined($_[0]) && !ref($_[0]) && $_[0] =~ /^-?[0-9]+$/ },
        Str        => sub { defined($_[0]) && !ref($_[0]) },
        ClassName  => sub { Mouse::is_class_loaded($_[0]) },
        Ref        => sub { ref($_[0]) },

        ScalarRef  => sub { ref($_[0]) eq 'SCALAR' },
        ArrayRef   => sub { ref($_[0]) eq 'ARRAY'  },
        HashRef    => sub { ref($_[0]) eq 'HASH'   },
        CodeRef    => sub { ref($_[0]) eq 'CODE'   },
        RegexpRef  => sub { ref($_[0]) eq 'Regexp' },
        GlobRef    => sub { ref($_[0]) eq 'GLOB'   },

        FileHandle => sub {
            ref($_[0]) eq 'GLOB' && openhandle($_[0])
            or
            blessed($_[0]) && $_[0]->isa("IO::Handle")
        },

        Object     => sub { blessed($_[0]) && blessed($_[0]) ne 'Regexp' },
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
    $TYPE{$name} = sub { local $_=$_[0]; $constraint->($_) };
}

sub subtype {
    my $pkg = caller(0);
    my($name, %conf) = @_;
    if ($TYPE{$name} && $TYPE_SOURCE{$name} ne $pkg) {
        Carp::croak "The type constraint '$name' has already been created in $TYPE_SOURCE{$name} and cannot be created again in $pkg";
    };
    my $constraint = $conf{where} || do {
        my $as = delete $conf{as} || 'Any';
        if (! exists $TYPE{$as}) { # Perhaps it's a parameterized source?
            Mouse::Meta::Attribute::_build_type_constraint($as);
        }
        $TYPE{$as};
    };
    my $as         = $conf{as} || '';

    $TYPE_SOURCE{$name} = $pkg;

    if ($as = $TYPE{$as}) {
        $TYPE{$name} = sub { local $_=$_[0]; $as->($_) && $constraint->($_) };
    } else {
        $TYPE{$name} = sub { local $_=$_[0]; $constraint->($_) };
    }
    return $name;
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

        if (! $TYPE{$type}) {
            # looks parameterized
            if ($type =~ /^[^\[]+\[.+\]$/) {
                Mouse::Meta::Attribute::_build_type_constraint($type);
            } else {
                Carp::croak "Could not find the type constraint ($type) to coerce from"
            }
        }

        push @{ $COERCE_KEYS{$name} }, $type;
        $COERCE{$name}->{$type} = $code;
    }
}

sub class_type {
    my($name, $conf) = @_;
    if ($conf && $conf->{class}) {
        # No, you're using this wrong
        warn "class_type() should be class_type(ClassName). Perhaps you're looking for subtype $name => as '$conf->{class}'?";
        subtype($name, as => $conf->{class});
    } else {
        subtype(
            $name => where => sub { $_->isa($name) }
        );
    }
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
            next unless $TYPE{$coerce_type}->($value);
            $_ = $value;
            $_ = $COERCE{$type}->{$coerce_type}->($value);
            return $_ if $type_constraint->($_);
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

=head1 FUNCTIONS

=over 4

=item B<subtype 'Name' => as 'Parent' => where { } ...>

=item B<subtype as 'Parent' => where { } ...>

=item B<class_type ($class, ?$options)>

=item B<role_type ($role, ?$options)>

=item B<enum (\@values)>

=back

=cut


