package Mouse::Util::TypeConstraints;
use strict;
use warnings;

use Exporter;

use Carp ();
use Scalar::Util qw/blessed looks_like_number openhandle/;

use Mouse::Util qw(does_role not_supported);
use Mouse::Meta::Module; # class_of
use Mouse::Meta::TypeConstraint;

our @ISA    = qw(Exporter);
our @EXPORT = qw(
    as where message from via type subtype coerce class_type role_type enum
    find_type_constraint
);

my %TYPE;
my %TYPE_SOURCE;
my %COERCE;
my %COERCE_KEYS;

sub as ($) {
    return(as => $_[0]);
}
sub where (&) {
    return(where => $_[0])
}
sub message (&) {
    return(message => $_[0])
}

sub from    { @_ }
sub via (&) { $_[0] }

BEGIN {
    my %builtins = (
        Any        => sub { 1 },
        Item       => sub { 1 },

        Bool       => sub { $_[0] ? $_[0] eq '1' : 1 },
        Undef      => sub { !defined($_[0]) },
        Defined    => sub { defined($_[0]) },
        Value      => sub { defined($_[0]) && !ref($_[0]) },
        Num        => sub { !ref($_[0]) && looks_like_number($_[0]) },
        Int        => sub { defined($_[0]) && !ref($_[0]) && $_[0] =~ /^-?[0-9]+$/ },
        Str        => sub { defined($_[0]) && !ref($_[0]) },
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

        ClassName  => sub { Mouse::Util::is_class_loaded($_[0]) },
        RoleName   => sub { (Mouse::Util::find_meta($_[0]) || return 0)->isa('Mouse::Meta::Role') },
    );

    while (my ($name, $code) = each %builtins) {
        $TYPE{$name} = Mouse::Meta::TypeConstraint->new(
            name                      => $name,
            _compiled_type_constraint => $code,
        );
        $TYPE_SOURCE{$name} = __PACKAGE__;
    }

    sub optimized_constraints { \%TYPE }

    my @builtins = keys %TYPE;
    sub list_all_builtin_type_constraints { @builtins }

    sub list_all_type_constraints         { keys %TYPE }
}

sub type {
    my $name;
    my %conf;

    if(@_ == 1 && ref $_[0]){ # type { where => ... }
        %conf = %{$_[0]};
    }
    elsif(@_ == 2 && ref $_[1]){ # type $name => { where => ... }*
        $name = $_[0];
        %conf = %{$_[1]};
    }
    elsif(@_ % 2){ # odd number of arguments
        $name = shift;
        %conf = @_;
    }
    else{
        %conf = @_;
    }

    $name = '__ANON__' if !defined $name;

    my $pkg = caller;

    if ($TYPE{$name} && $TYPE_SOURCE{$name} ne $pkg) {
        Carp::croak "The type constraint '$name' has already been created in $TYPE_SOURCE{$name} and cannot be created again in $pkg";
    }

    my $constraint = $conf{where} || do {
        my $as = delete $conf{as} || 'Any';
        ($TYPE{$as} ||= _build_type_constraint($as))->{_compiled_type_constraint};
    };

    my $tc = Mouse::Meta::TypeConstraint->new(
        name                      => $name,
        _compiled_type_constraint => sub {
            local $_ = $_[0];
            return &{$constraint};
        },
    );

    $TYPE_SOURCE{$name} = $pkg;
    $TYPE{$name}        = $tc;

    return $tc;
}

sub subtype {
    my $name;
    my %conf;

    if(@_ == 1 && ref $_[0]){ # type { where => ... }
        %conf = %{$_[0]};
    }
    elsif(@_ == 2 && ref $_[1]){ # type $name => { where => ... }*
        $name = $_[0];
        %conf = %{$_[1]};
    }
    elsif(@_ % 2){ # odd number of arguments
        $name = shift;
        %conf = @_;
    }
    else{
        %conf = @_;
    }

    $name = '__ANON__' if !defined $name;

    my $pkg = caller;

    if ($TYPE{$name} && $TYPE_SOURCE{$name} ne $pkg) {
        Carp::croak "The type constraint '$name' has already been created in $TYPE_SOURCE{$name} and cannot be created again in $pkg";
    }

    my $constraint    = delete $conf{where};
    my $as_constraint = find_or_create_isa_type_constraint(delete $conf{as} || 'Any')
        ->{_compiled_type_constraint};

    my $tc = Mouse::Meta::TypeConstraint->new(
        name => $name,
        _compiled_type_constraint => (
            $constraint ? 
            sub {
                local $_ = $_[0];
                $as_constraint->($_[0]) && $constraint->($_[0])
            } :
            sub {
                local $_ = $_[0];
                $as_constraint->($_[0]);
            }
        ),
        %conf,
    );

    $TYPE_SOURCE{$name} = $pkg;
    $TYPE{$name}        = $tc;

    return $tc;
}

sub coerce {
    my $name = shift;

    Carp::croak "Cannot find type '$name', perhaps you forgot to load it."
        unless $TYPE{$name};

    unless ($COERCE{$name}) {
        $COERCE{$name}      = {};
        $COERCE_KEYS{$name} = [];
    }

    while (my($type, $code) = splice @_, 0, 2) {
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

        push @{ $COERCE_KEYS{$name} }, $type;
        $COERCE{$name}->{$type} = $code;
    }
    return;
}

sub class_type {
    my($name, $conf) = @_;
    if ($conf && $conf->{class}) {
        # No, you're using this wrong
        warn "class_type() should be class_type(ClassName). Perhaps you're looking for subtype $name => as '$conf->{class}'?";
        subtype $name => (as => $conf->{class});
    }
    else {
        subtype $name => (
            where => sub { blessed($_) && $_->isa($name) },
        );
    }
}

sub role_type {
    my($name, $conf) = @_;
    my $role = $conf->{role};
    subtype $name => (
        where => sub { does_role($_, $role) },
    );
}

# this is an original method for Mouse
sub typecast_constraints {
    my($class, $pkg, $types, $value) = @_;
    Carp::croak("wrong arguments count") unless @_ == 4;

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
    my($spec) = @_;

    my $code;
    $spec =~ s/\s+//g;

    if ($spec =~ /\A (\w+) \[ (.+) \] \z/xms) {
        # parameterized
        my $constraint = $1;
        my $param      = $2;
        my $parent;

        if ($constraint eq 'Maybe') {
            $parent = _build_type_constraint('Undef');
        }
        else {
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
    my($type) = @_;
    if(blessed($type) && $type->isa('Mouse::Meta::TypeConstraint')){
        return $type;
    }
    else{
        return $TYPE{$type};
    }
}

sub find_or_create_does_type_constraint{
    not_supported;
}

sub find_or_create_isa_type_constraint {
    my $type_constraint = shift;

    Carp::confess("Got isa => type_constraints, but Mouse does not yet support parameterized types for containers other than ArrayRef and HashRef and Maybe (rt.cpan.org #39795)")
        if $type_constraint =~ /\A ( [^\[]+ ) \[\.+\] \z/xms &&
           $1 ne 'ArrayRef' &&
           $1 ne 'HashRef'  &&
           $1 ne 'Maybe'
    ;


    $type_constraint =~ s/\s+//g;

    my $tc =  find_type_constraint($type_constraint);
    if (!$tc) {
        my @type_constraints = split /\|/, $type_constraint;
        if (@type_constraints == 1) {
            $tc = $TYPE{$type_constraints[0]} ||
                _build_type_constraint($type_constraints[0]);
        }
        else {
            my @code_list = map {
                $TYPE{$_} || _build_type_constraint($_)
            } @type_constraints;

            $tc = Mouse::Meta::TypeConstraint->new(
                name => $type_constraint,

                _compiled_type_constraint => sub {
                    foreach my $code (@code_list) {
                        return 1 if $code->check($_[0]);
                    }
                    return 0;
                },
            );
        }
    }
    return $tc;
}

1;

__END__

=head1 NAME

Mouse::Util::TypeConstraints - Type constraint system for Mouse

=head2 SYNOPSIS

  use Mouse::Util::TypeConstraints;

  subtype 'Natural'
      => as 'Int'
      => where { $_ > 0 };

  subtype 'NaturalLessThanTen'
      => as 'Natural'
      => where { $_ < 10 }
      => message { "This number ($_) is not less than ten!" };

  coerce 'Num'
      => from 'Str'
        => via { 0+$_ };

  enum 'RGBColors' => qw(red green blue);

  no Mouse::Util::TypeConstraints;

=head1 DESCRIPTION

This module provides Mouse with the ability to create custom type
constraints to be used in attribute definition.

=head2 Important Caveat

This is B<NOT> a type system for Perl 5. These are type constraints,
and they are not used by Mouse unless you tell it to. No type
inference is performed, expressions are not typed, etc. etc. etc.

A type constraint is at heart a small "check if a value is valid"
function. A constraint can be associated with an attribute. This
simplifies parameter validation, and makes your code clearer to read,
because you can refer to constraints by name.

=head2 Slightly Less Important Caveat

It is B<always> a good idea to quote your type names.

This prevents Perl from trying to execute the call as an indirect
object call. This can be an issue when you have a subtype with the
same name as a valid class.

For instance:

  subtype DateTime => as Object => where { $_->isa('DateTime') };

will I<just work>, while this:

  use DateTime;
  subtype DateTime => as Object => where { $_->isa('DateTime') };

will fail silently and cause many headaches. The simple way to solve
this, as well as future proof your subtypes from classes which have
yet to have been created, is to quote the type name:

  use DateTime;
  subtype 'DateTime' => as 'Object' => where { $_->isa('DateTime') };

=head2 Default Type Constraints

This module also provides a simple hierarchy for Perl 5 types, here is
that hierarchy represented visually.

  Any
  Item
      Bool
      Maybe[`a]
      Undef
      Defined
          Value
              Num
                Int
              Str
                ClassName
                RoleName
          Ref
              ScalarRef
              ArrayRef[`a]
              HashRef[`a]
              CodeRef
              RegexpRef
              GlobRef
                FileHandle
              Object
                Role

B<NOTE:> Any type followed by a type parameter C<[`a]> can be
parameterized, this means you can say:

  ArrayRef[Int]    # an array of integers
  HashRef[CodeRef] # a hash of str to CODE ref mappings
  Maybe[Str]       # value may be a string, may be undefined

If Mouse finds a name in brackets that it does not recognize as an
existing type, it assumes that this is a class name, for example
C<ArrayRef[DateTime]>.

B<NOTE:> Unless you parameterize a type, then it is invalid to include
the square brackets. I.e. C<ArrayRef[]> will be treated as a new type
name, I<not> as a parameterization of C<ArrayRef>.

B<NOTE:> The C<Undef> type constraint for the most part works
correctly now, but edge cases may still exist, please use it
sparingly.

B<NOTE:> The C<ClassName> type constraint does a complex package
existence check. This means that your class B<must> be loaded for this
type constraint to pass.

B<NOTE:> The C<RoleName> constraint checks a string is a I<package
name> which is a role, like C<'MyApp::Role::Comparable'>. The C<Role>
constraint checks that an I<object does> the named role.

=head2 Type Constraint Naming

Type name declared via this module can only contain alphanumeric
characters, colons (:), and periods (.).

Since the types created by this module are global, it is suggested
that you namespace your types just as you would namespace your
modules. So instead of creating a I<Color> type for your
B<My::Graphics> module, you would call the type
I<My::Graphics::Types::Color> instead.

=head2 Use with Other Constraint Modules

This module can play nicely with other constraint modules with some
slight tweaking. The C<where> clause in types is expected to be a
C<CODE> reference which checks it's first argument and returns a
boolean. Since most constraint modules work in a similar way, it
should be simple to adapt them to work with Mouse.

For instance, this is how you could use it with
L<Declare::Constraints::Simple> to declare a completely new type.

  type 'HashOfArrayOfObjects',
      {
      where => IsHashRef(
          -keys   => HasLength,
          -values => IsArrayRef(IsObject)
      )
  };

Here is an example of using L<Test::Deep> and it's non-test
related C<eq_deeply> function.

  type 'ArrayOfHashOfBarsAndRandomNumbers'
      => where {
          eq_deeply($_,
              array_each(subhashof({
                  bar           => isa('Bar'),
                  random_number => ignore()
              })))
        };

=head1 METHODS

=head2 optimized_constraints -> HashRef[CODE]

Returns the simple type constraints that Mouse understands.

=head1 FUNCTIONS

=over 4

=item C<< subtype 'Name' => as 'Parent' => where { } ... -> Mouse::Meta::TypeConstraint >>

=item C<< subtype as 'Parent' => where { } ...  -> Mouse::Meta::TypeConstraint >>

=item C<< class_type ($class, ?$options) -> Mouse::Meta::TypeConstraint >>

=item C<< role_type ($role, ?$options) -> Mouse::Meta::TypeConstraint >>

=item C<< enum (\@values) -> Mouse::Meta::TypeConstraint >>

=back

=over 4

=item C<< find_type_constraint(Type) -> Mouse::Meta::TypeConstraint >>

=back

=head1 THANKS

Much of this documentation was taken from C<Moose::Util::TypeConstraints>

=head1 SEE ALSO

L<Moose::Util::TypeConstraints>

=cut


