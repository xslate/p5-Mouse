package Mouse::Util::TypeConstraints;
use Mouse::Util qw(does_role not_supported); # enables strict and warnings

use Carp qw(confess);
use Scalar::Util ();

use Mouse::Meta::TypeConstraint;
use Mouse::Exporter;

Mouse::Exporter->setup_import_methods(
    as_is => [qw(
        as where message optimize_as
        from via

        type subtype class_type role_type duck_type
        enum
        coerce

        find_type_constraint
    )],
);

my %TYPE;

sub as          ($) { (as          => $_[0]) }
sub where       (&) { (where       => $_[0]) }
sub message     (&) { (message     => $_[0]) }
sub optimize_as (&) { (optimize_as => $_[0]) }

sub from    { @_ }
sub via (&) { $_[0] }

BEGIN {
    my %builtins = (
        Any        => undef, # null check
        Item       => undef, # null check
        Maybe      => undef, # null check

        Bool       => \&Bool,
        Undef      => \&Undef,
        Defined    => \&Defined,
        Value      => \&Value,
        Num        => \&Num,
        Int        => \&Int,
        Str        => \&Str,
        Ref        => \&Ref,

        ScalarRef  => \&ScalarRef,
        ArrayRef   => \&ArrayRef,
        HashRef    => \&HashRef,
        CodeRef    => \&CodeRef,
        RegexpRef  => \&RegexpRef,
        GlobRef    => \&GlobRef,

        FileHandle => \&FileHandle,

        Object     => \&Object,

        ClassName  => \&ClassName,
        RoleName   => \&RoleName,
    );

    while (my ($name, $code) = each %builtins) {
        $TYPE{$name} = Mouse::Meta::TypeConstraint->new(
            name      => $name,
            optimized => $code,
        );
    }

    sub optimized_constraints { # DEPRECATED
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
        $name = $args{name};
    }

    $args{name} = $name;
    my $parent;
    if($mode eq 'subtype'){
        $parent = delete $args{as};
        if(!$parent){
            $parent = delete $args{name};
            $name   = undef;
        }
    }

    if(defined $name){
        my $package_defined_in = $args{package_defined_in} ||= caller(1);
        my $existing = $TYPE{$name};
        if($existing && $existing->{package_defined_in} ne $package_defined_in){
            confess("The type constraint '$name' has already been created in "
                  . "$existing->{package_defined_in} and cannot be created again in $package_defined_in");
        }
    }
    else{
        $args{name} = '__ANON__';
    }

    $args{constraint} = delete $args{where}        if exists $args{where};
    $args{optimized}  = delete $args{optimized_as} if exists $args{optimized_as};

    my $constraint;
    if($mode eq 'subtype'){
        $constraint = find_or_create_isa_type_constraint($parent)->create_child_type(%args);
    }
    else{
        $constraint = Mouse::Meta::TypeConstraint->new(%args);
    }

    if(defined $name){
        return $TYPE{$name} = $constraint;
    }
    else{
        return $constraint;
    }
}

sub type {
    return _create_type('type', @_);
}

sub subtype {
    return _create_type('subtype', @_);
}

sub coerce {
    my $type_name = shift;

    my $type = find_type_constraint($type_name)
        or confess("Cannot find type '$type_name', perhaps you forgot to load it.");

    $type->_add_type_coercions(@_);
    return;
}

sub class_type {
    my($name, $options) = @_;
    my $class = $options->{class} || $name;
    return _create_type 'subtype', $name => (
        as           => 'Object',
        optimized_as => Mouse::Util::generate_isa_predicate_for($class),

        type => 'Class',
    );
}

sub role_type {
    my($name, $options) = @_;
    my $role = $options->{role} || $name;
    return _create_type 'subtype', $name => (
        as           => 'Object',
        optimized_as => sub { Scalar::Util::blessed($_[0]) && does_role($_[0], $role) },

        type => 'Role',
    );
}

sub duck_type {
    my($name, @methods);

    if(!(@_ == 1 && ref($_[0]) eq 'ARRAY')){
        $name = shift;
    }

    @methods = (@_ == 1 && ref($_[0]) eq 'ARRAY') ? @{$_[0]} : @_;

    return _create_type 'type', $name => (
        optimized_as => Mouse::Util::generate_can_predicate_for(\@methods),

        type => 'DuckType',
    );
}

sub enum {
    my($name, %valid);

    if(!(@_ == 1 && ref($_[0]) eq 'ARRAY')){
        $name = shift;
    }

    %valid = map{ $_ => undef } (@_ == 1 && ref($_[0]) eq 'ARRAY' ? @{$_[0]} : @_);

    return _create_type 'type', $name => (
        optimized_as  => sub{ defined($_[0]) && !ref($_[0]) && exists $valid{$_[0]} },

        type => 'Enum',
    );
}

sub _find_or_create_regular_type{
    my($spec)  = @_;

    return $TYPE{$spec} if exists $TYPE{$spec};

    my $meta = Mouse::Util::get_metaclass_by_name($spec)
        or return undef;

    if(Mouse::Util::is_a_metarole($meta)){
        return role_type($spec);
    }
    else{
        return class_type($spec);
    }
}

$TYPE{ArrayRef}{constraint_generator} = \&_parameterize_ArrayRef_for;
$TYPE{HashRef}{constraint_generator}  = \&_parameterize_HashRef_for;
$TYPE{Maybe}{constraint_generator}    = \&_parameterize_Maybe_for;

sub _find_or_create_parameterized_type{
    my($base, $param) = @_;

    my $name = sprintf '%s[%s]', $base->name, $param->name;

    $TYPE{$name} ||= $base->parameterize($param, $name);
}

sub _find_or_create_union_type{
    my @types = sort map{ $_->{type_constraints} ? @{$_->{type_constraints}} : $_ } @_;

    my $name = join '|', @types;

    $TYPE{$name} ||= Mouse::Meta::TypeConstraint->new(
        name              => $name,
        type_constraints  => \@types,

        type              => 'Union',
    );
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
            my $base = _find_or_create_regular_type( substr($spec, $start, $i - $start) )
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
            my $type = _find_or_create_regular_type( substr($spec, $start, $i - $start) );

            if(!defined $type){
                # XXX: Mouse creates a new class type, but Moose does not.
                $type = class_type( substr($spec, $start, $i - $start) );
            }

            push @list, $type;

            ($i, $subtype) = _parse_type($spec, $i+1)
                or return;

            $start = $i+1; # reset

            push @list, $subtype;
        }
    }
    if($i - $start){
        my $type = _find_or_create_regular_type( substr $spec, $start, $i - $start );

        if(defined $type){
            push @list, $type;
        }
        elsif($start != 0) {
            # RT #50421
            # create a new class type
            push @list, class_type( substr $spec, $start, $i - $start );
        }
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
    return $spec if Mouse::Util::is_a_type_constraint($spec);

    $spec =~ s/\s+//g;
    return $TYPE{$spec};
}

sub find_or_parse_type_constraint {
    my($spec) = @_;
    return $spec if Mouse::Util::is_a_type_constraint($spec);

    $spec =~ s/\s+//g;
    return $TYPE{$spec} || do{
        my($pos, $type) = _parse_type($spec, 0);
        $type;
    };
}

sub find_or_create_does_type_constraint{
    # XXX: Moose does not register a new role_type, but Mouse does.
    return find_or_parse_type_constraint(@_) || role_type(@_);
}

sub find_or_create_isa_type_constraint {
    # XXX: Moose does not register a new class_type, but Mouse does.
    return find_or_parse_type_constraint(@_) || class_type(@_);
}

1;
__END__

=head1 NAME

Mouse::Util::TypeConstraints - Type constraint system for Mouse

=head1 VERSION

This document describes Mouse version 0.47

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
              Str
                  Num
                      Int
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

=head2 C<< list_all_builtin_type_constraints -> (Names) >>

Returns the names of builtin type constraints.

=head2 C<< list_all_type_constraints -> (Names) >>

Returns the names of all the type constraints.

=head1 FUNCTIONS

=over 4

=item C<< type $name => where { } ... -> Mouse::Meta::TypeConstraint >>

=item C<< subtype $name => as $parent => where { } ... -> Mouse::Meta::TypeConstraint >>

=item C<< subtype as $parent => where { } ...  -> Mouse::Meta::TypeConstraint >>

=item C<< class_type ($class, ?$options) -> Mouse::Meta::TypeConstraint >>

=item C<< role_type ($role, ?$options) -> Mouse::Meta::TypeConstraint >>

=item C<< duck_type($name, @methods | \@methods) -> Mouse::Meta::TypeConstraint >>

=item C<< duck_type(\@methods) -> Mouse::Meta::TypeConstraint >>

=item C<< enum($name, @values | \@values) -> Mouse::Meta::TypeConstraint >>

=item C<< enum (\@values) -> Mouse::Meta::TypeConstraint >>

=item C<< coerce $type => from $another_type, via { }, ... >>

=back

=over 4

=item C<< find_type_constraint(Type) -> Mouse::Meta::TypeConstraint >>

=back

=head1 THANKS

Much of this documentation was taken from C<Moose::Util::TypeConstraints>

=head1 SEE ALSO

L<Moose::Util::TypeConstraints>

=cut


