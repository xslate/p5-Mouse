package Mouse::Util::TypeConstraints;
use strict;
use warnings;

use Exporter;

use Carp qw(confess);
use Scalar::Util qw/blessed looks_like_number openhandle/;

use Mouse::Util qw(does_role not_supported);
use Mouse::Meta::Module; # class_of
use Mouse::Meta::TypeConstraint;

use constant _DEBUG => !!$ENV{TC_DEBUG};

our @ISA    = qw(Exporter);
our @EXPORT = qw(
    as where message from via type subtype coerce class_type role_type enum
    find_type_constraint
);

my %TYPE;
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
        Any        => undef, # null check
        Item       => undef, # null check
        Maybe      => undef, # null check

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
            package_defined_in        => __PACKAGE__,
        );
    }

    sub optimized_constraints {
        Carp::cluck('optimized_constraints() has been deprecated');
        return \%TYPE;
    }

    my @builtins = keys %TYPE;
    sub list_all_builtin_type_constraints { @builtins }

    sub list_all_type_constraints         { keys %TYPE }
}

sub _create_type{
    my $mode = shift;

    my $name;
    my %args;

    if(@_ == 1 && ref $_[0]){   # @_ : { name => $name, where => ... }
        %args = %{$_[0]};
    }
    elsif(@_ == 2 && ref $_[1]){ # @_ : $name => { where => ... }
        $name = $_[0];
        %args = %{$_[1]};
    }
    elsif(@_ % 2){               # @_ : $name => ( where => ... )
        ($name, %args) = @_;
    }
    else{                        # @_ : (name => $name, where => ...)
        %args = @_;
    }

    if(!defined $name){
        if(!defined($name = $args{name})){
            $name = '__ANON__';
        }
    }

    $args{name} = $name;

    my $package_defined_in = $args{package_defined_in} ||= caller(1);

    my $existing = $TYPE{$name};
    if($existing && $existing->{package_defined_in} ne $package_defined_in){
        confess("The type constraint '$name' has already been created in "
              . "$existing->{package_defined_in} and cannot be created again in $package_defined_in");
    }

    $args{constraint}                = delete($args{where})
        if exists $args{where};
    $args{_compiled_type_constraint} = delete $args{optimized_as}
        if exists $args{optimized_as};

    my $constraint;
    if($mode eq 'subtype'){
        my $parent = exists($args{as}) ? delete($args{as}) : delete($args{name});

        $parent     = find_or_create_isa_type_constraint($parent);
        $constraint = $parent->create_child_type(%args);
    }
    else{
        $constraint = Mouse::Meta::TypeConstraint->new(%args);
    }

    return $TYPE{$name} = $constraint;
}

sub type {
    return _create_type('type', @_);
}

sub subtype {
    return _create_type('subtype', @_);
}

sub coerce {
    my $name = shift;

    $name =~ s/\s+//g;
    confess "Cannot find type '$name', perhaps you forgot to load it."
        unless $TYPE{$name};

    unless ($COERCE{$name}) {
        $COERCE{$name}      = {};
        $COERCE_KEYS{$name} = [];
    }

    my $package_defined_in = caller;

    while (my($from, $action) = splice @_, 0, 2) {
        $from =~ s/\s+//g;

        confess "A coercion action already exists for '$from'"
            if $COERCE{$name}->{$from};

        my $type = find_or_parse_type_constraint($from, $package_defined_in);
        if (!$type) {
            confess "Could not find the type constraint ($from) to coerce from"
        }

        warn "# REGISTER COERCE $name, from $type\n" if _DEBUG;

        push @{ $COERCE_KEYS{$name} }, $type;
        $COERCE{$name}->{$from} = $action;
    }
    return;
}

sub class_type {
    my($name, $conf) = @_;
    if ($conf && $conf->{class}) {
        # No, you're using this wrong
        warn "class_type() should be class_type(ClassName). Perhaps you're looking for subtype $name => as '$conf->{class}'?";
        _create_type 'type', $name => (
            as   => $conf->{class},

            type => 'Class',
       );
    }
    else {
        _create_type 'type', $name => (
            optimized_as => sub { blessed($_[0]) && $_[0]->isa($name) },

            type => 'Class',
        );
    }
}

sub role_type {
    my($name, $conf) = @_;
    my $role = ($conf && $conf->{role}) ? $conf->{role} : $name;
    _create_type 'type', $name => (
        optimized_as => sub { blessed($_[0]) && does_role($_[0], $role) },

        type => 'Role',
    );
}

# this is an original method for Mouse
sub typecast_constraints {
    my($class, $pkg, $types, $value) = @_;
    Carp::croak("wrong arguments count") unless @_ == 4;

    local $_;
    for my $type ($types->{type_constraints} ? @{$types->{type_constraints}} : $types ) {
        for my $coerce_type (@{ $COERCE_KEYS{$type}}) {

            if(_DEBUG){
                warn sprintf "# COERCE: from %s to %s for %s (%s)\n",
                    $coerce_type, $type, defined($value) ? "'$value'" : 'undef',
                    $coerce_type->check($value) ? "try" : "skip";
            }

            next if !$coerce_type->check($value);

            # try to coerce
            $_ = $value;
            my $coerced = $COERCE{$type}->{$coerce_type}->($value); # coerce

            if(_DEBUG){
                warn sprintf "# COERCE: got %s, which is%s %s\n",
                    defined($coerced) ? $coerced : 'undef', $types->check($coerced) ? '' : ' not', $types;
            }

            # check with $types, not $constraint
            return $coerced if $types->check($coerced);
        }
    }
    return $value; # returns original $value
}

sub enum {
    my($name, %valid);

    # enum ['small', 'medium', 'large']
    if (ref($_[0]) eq 'ARRAY') {
        %valid = map{ $_ => undef } @{ $_[0] };
        $name  = sprintf '(%s)', join '|', sort @{$_[0]};
    }
    # enum size => 'small', 'medium', 'large'
    else{
        $name  = shift;
        %valid = map{ $_ => undef } @_;
    }
    return _create_type 'type', $name => (
        optimized_as  => sub{ defined($_[0]) && !ref($_[0]) && exists $valid{$_[0]} },

        type => 'Enum',
    );
}

sub _find_or_create_regular_type{
    my($spec)  = @_;

    return $TYPE{$spec} if exists $TYPE{$spec};

    my $meta  = Mouse::Meta::Module::class_of($spec);

    if(!$meta){
        return;
    }

    my $check;
    my $type;
    if($meta && $meta->isa('Mouse::Meta::Role')){
        $check = sub{
            return blessed($_[0]) && $_[0]->does($spec);
        };
        $type = 'Role';
    }
    else{
        $check = sub{
            return blessed($_[0]) && $_[0]->isa($spec);
        };
        $type = 'Class';
    }

    warn "#CREATE a $type type for $spec\n" if _DEBUG;

    return $TYPE{$spec} = Mouse::Meta::TypeConstraint->new(
        name                      => $spec,
        _compiled_type_constraint => $check,

        type                      => $type,
    );
}

$TYPE{ArrayRef}{constraint_generator} = sub {
    my($type_parameter) = @_;
    my $check = $type_parameter->{_compiled_type_constraint};

    return sub{
        foreach my $value (@{$_}) {
            return undef unless $check->($value);
        }
        return 1;
    }
};
$TYPE{HashRef}{constraint_generator} = sub {
    my($type_parameter) = @_;
    my $check = $type_parameter->{_compiled_type_constraint};

    return sub{
        foreach my $value(values %{$_}){
            return undef unless $check->($value);
        }
        return 1;
    };
};

# 'Maybe' type accepts 'Any', so it requires parameters
$TYPE{Maybe}{constraint_generator} = sub {
    my($type_parameter) = @_;
    my $check = $type_parameter->{_compiled_type_constraint};

    return sub{
        return !defined($_) || $check->($_);
    };
};

sub _find_or_create_parameterized_type{
    my($base, $param) = @_;

    my $name = sprintf '%s[%s]', $base->name, $param->name;

    $TYPE{$name} ||= do{
        warn "#CREATE a Parameterized type for $name\n" if _DEBUG;

        my $generator = $base->{constraint_generator};

        if(!$generator){
            confess("The $name constraint cannot be used, because $param doesn't subtype from a parameterizable type");
        }

        Mouse::Meta::TypeConstraint->new(
            name               => $name,
            parent             => $base,
            constraint         => $generator->($param),

            type               => 'Parameterized',
        );
    }
}
sub _find_or_create_union_type{
    my @types              = map{ $_->{type_constraints} ? @{$_->{type_constraints}} : $_ } @_;

    my $name = join '|', map{ $_->name } @types;

    $TYPE{$name} ||= do{
        warn "# CREATE a Union type for ", Mouse::Util::english_list(@types),"\n" if _DEBUG;

        my @checks = map{ $_->{_compiled_type_constraint} } @types;
        my $check = sub{
            foreach my $c(@checks){
                return 1 if $c->($_[0]);
            }
            return 0;
        };

        return Mouse::Meta::TypeConstraint->new(
            name                      => $name,
            _compiled_type_constraint => $check,
            type_constraints          => \@types,

            type                      => 'Union',
        );
    };
}

# The type parser
sub _parse_type{
    my($spec, $start) = @_;

    my @list;
    my $subtype;

    my $len = length $spec;
    my $i;

    for($i = $start; $i < $len; $i++){
        my $char = substr($spec, $i, 1);

        if($char eq '['){
            my $base = _find_or_create_regular_type( substr($spec, $start, $i - $start))
                or return;

            ($i, $subtype) = _parse_type($spec, $i+1)
                or return;
            $start = $i+1; # reset

            push @list, _find_or_create_parameterized_type($base => $subtype);
        }
        elsif($char eq ']'){
            $len = $i+1;
            last;
        }
        elsif($char eq '|'){
            my $type = _find_or_create_regular_type( substr($spec, $start, $i - $start))
                or return;

            push @list, $type;

            ($i, $subtype) = _parse_type($spec, $i+1)
                or return;

            $start = $i+1; # reset

            push @list, $subtype;
        }
    }
    if($i - $start){
        push @list, _find_or_create_regular_type(substr $spec, $start, $i - $start);
    }

    if(@list == 0){
       return;
    }
    elsif(@list == 1){
        return ($len, $list[0]);
    }
    else{
        return ($len, _find_or_create_union_type(@list));
    }
}


sub find_type_constraint {
    my($spec) = @_;
    return $spec if blessed($spec) && $spec->isa('Mouse::Meta::TypeConstraint');

    $spec =~ s/\s+//g;
    return $TYPE{$spec};
}

sub find_or_parse_type_constraint {
    my($spec) = @_;
    return $spec if blessed($spec) && $spec->isa('Mouse::Meta::TypeConstraint');

    $spec =~ s/\s+//g;
    return $TYPE{$spec} || do{
        my($pos, $type) = _parse_type($spec, 0);
        $type;
    };
}

sub find_or_create_does_type_constraint{
    my $type = find_or_parse_type_constriant(@_) || role_type(@_);

    if($type->{type} && $type->{type} ne 'Role'){
        Carp::cluck("$type is not a role type");
    }
    return $type;
}

sub find_or_create_isa_type_constraint {
    return find_or_parse_type_constraint(@_) || class_type(@_);
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


