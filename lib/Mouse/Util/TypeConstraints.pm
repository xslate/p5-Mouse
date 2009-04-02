package Mouse::Util::TypeConstraints;
use strict;
use warnings;
use base 'Exporter';

use Carp ();
use Scalar::Util qw/blessed looks_like_number openhandle/;
use Mouse::Meta::TypeConstraint;

our @EXPORT = qw(
    as where message from via type subtype coerce class_type role_type enum
    find_type_constraint
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

BEGIN {
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
    while (my ($name, $code) = each %TYPE) {
        $TYPE{$name} = Mouse::Meta::TypeConstraint->new( _compiled_type_constraint => $code, name => $name );
    }

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
    my $constraint = $conf{where} || do {
        my $as = delete $conf{as} || 'Any';
        if (! exists $TYPE{$as}) {
            $TYPE{$as} = _build_type_constraint($as);
        }
        $TYPE{$as};
    };

    $TYPE_SOURCE{$name} = $pkg;
    $TYPE{$name} = Mouse::Meta::TypeConstraint->new(
        name => $name,
        _compiled_type_constraint => sub {
            local $_ = $_[0];
            if (ref $constraint eq 'CODE') {
                $constraint->($_[0])
            } else {
                $constraint->check($_[0])
            }
        }
    );
}

sub subtype {
    my $pkg = caller(0);
    my($name, %conf) = @_;
    if ($TYPE{$name} && $TYPE_SOURCE{$name} ne $pkg) {
        Carp::croak "The type constraint '$name' has already been created in $TYPE_SOURCE{$name} and cannot be created again in $pkg";
    };
    my $constraint = $conf{where};
    my $as_constraint = find_or_create_isa_type_constraint($conf{as} || 'Any');

    $TYPE_SOURCE{$name} = $pkg;
    $TYPE{$name} = Mouse::Meta::TypeConstraint->new(
        name => $name,
        _compiled_type_constraint => (
            $constraint ? 
            sub {
                local $_ = $_[0];
                $as_constraint->check($_[0]) && $constraint->($_[0])
            } :
            sub {
                local $_ = $_[0];
                $as_constraint->check($_[0]);
            }
        ),
    );

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
                $TYPE{$type} = _build_type_constraint($type);
            } else {
                Carp::croak "Could not find the type constraint ($type) to coerce from"
            }
        }

        unshift @{ $COERCE_KEYS{$name} }, $type;
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

# this is an original method for Mouse
sub typecast_constraints {
    my($class, $pkg, $types, $value) = @_;
    Carp::croak("wrong arguments count") unless @_==4;

    local $_;
    for my $type ( split /\|/, $types ) {
        next unless $COERCE{$type};
        for my $coerce_type (@{ $COERCE_KEYS{$type}}) {
            $_ = $value;
            next unless $TYPE{$coerce_type}->check($value);
            $_ = $value;
            $_ = $COERCE{$type}->{$coerce_type}->($value);
            return $_ if $types->check($_);
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

sub _build_type_constraint {

    my $spec = shift;
    my $code;
    $spec =~ s/\s+//g;
    if ($spec =~ /^([^\[]+)\[(.+)\]$/) {
        # parameterized
        my $constraint = $1;
        my $param      = $2;
        my $parent;
        if ($constraint eq 'Maybe') {
            $parent = _build_type_constraint('Undef');
        } else {
            $parent = _build_type_constraint($constraint);
        }
        my $child = _build_type_constraint($param);
        if ($constraint eq 'ArrayRef') {
            my $code_str = 
                "#line " . __LINE__ . ' "' . __FILE__ . "\"\n" .
                "sub {\n" .
                "    if (\$parent->check(\$_[0])) {\n" .
                "        foreach my \$e (\@{\$_[0]}) {\n" .
                "            return () unless \$child->check(\$e);\n" .
                "        }\n" .
                "        return 1;\n" .
                "    }\n" .
                "    return ();\n" .
                "};\n"
            ;
            $code = eval $code_str or Carp::confess("Failed to generate inline type constraint: $@");
        } elsif ($constraint eq 'HashRef') {
            my $code_str = 
                "#line " . __LINE__ . ' "' . __FILE__ . "\"\n" .
                "sub {\n" .
                "    if (\$parent->check(\$_[0])) {\n" .
                "        foreach my \$e (values \%{\$_[0]}) {\n" .
                "            return () unless \$child->check(\$e);\n" .
                "        }\n" .
                "        return 1;\n" .
                "    }\n" .
                "    return ();\n" .
                "};\n"
            ;
            $code = eval $code_str or Carp::confess($@);
        } elsif ($constraint eq 'Maybe') {
            my $code_str =
                "#line " . __LINE__ . ' "' . __FILE__ . "\"\n" .
                "sub {\n" .
                "    return \$child->check(\$_[0]) || \$parent->check(\$_[0]);\n" .
                "};\n"
            ;
            $code = eval $code_str or Carp::confess($@);
        } else {
            Carp::confess("Support for parameterized types other than Maybe, ArrayRef or HashRef is not implemented yet");
        }
        $TYPE{$spec} = Mouse::Meta::TypeConstraint->new( _compiled_type_constraint => $code, name => $spec );
    } else {
        $code = $TYPE{ $spec };
        if (! $code) {
            # is $spec a known role?  If so, constrain with 'does' instead of 'isa'
            require Mouse::Meta::Role;
            my $check = Mouse::Meta::Role->_metaclass_cache($spec)? 
                'does' : 'isa';
            my $code_str = 
                "#line " . __LINE__ . ' "' . __FILE__ . "\"\n" .
                "sub {\n" .
                "    Scalar::Util::blessed(\$_[0]) && \$_[0]->$check('$spec');\n" .
                "}"
            ;
            $code = eval $code_str  or Carp::confess($@);
            $TYPE{$spec} = Mouse::Meta::TypeConstraint->new( _compiled_type_constraint => $code, name => $spec );
        }
    }
    return Mouse::Meta::TypeConstraint->new( _compiled_type_constraint => $code, name => $spec );
}

sub find_type_constraint {
    my $type_constraint = shift;
    return $TYPE{$type_constraint};
}

sub find_or_create_isa_type_constraint {
    my $type_constraint = shift;

    my $code;

    $type_constraint =~ s/\s+//g;

    $code = $TYPE{$type_constraint};
    if (! $code) {
        my @type_constraints = split /\|/, $type_constraint;
        if (@type_constraints == 1) {
            $code = $TYPE{$type_constraints[0]} ||
                _build_type_constraint($type_constraints[0]);
        } else {
            my @code_list = map {
                $TYPE{$_} || _build_type_constraint($_)
            } @type_constraints;
            $code = Mouse::Meta::TypeConstraint->new(
                _compiled_type_constraint => sub {
                    my $i = 0;
                    for my $code (@code_list) {
                        return 1 if $code->check($_[0]);
                    }
                    return 0;
                },
                name => $type_constraint,
            );
        }
    }
    return $code;
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


