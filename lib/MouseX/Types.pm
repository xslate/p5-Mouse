package MouseX::Types;
use strict;
use warnings;

require Mouse::TypeRegistry;

sub import {
    my $class  = shift;
    my %args   = @_;
    my $caller = caller(0);

    no strict 'refs';
    *{"$caller\::import"} = sub { my $pkg = caller(0); _import($caller, $pkg, @_) };
    push @{"$caller\::ISA"}, 'MouseX::Types::Base';

    if (defined $args{'-declare'} && ref($args{'-declare'}) eq 'ARRAY') {
        my $storage = $caller->type_storage($caller);
        for my $name (@{ $args{'-declare'} }) {
            $storage->{$name} = "$caller\::$name";
            *{"$caller\::$name"} = sub () { $caller->type_storage->{$name} };
        }
    }

    return Mouse::TypeRegistry->import( callee => $caller );
}

sub _import {
    my($type_class, $pkg, @types) = @_;
    no strict 'refs';
    for my $name (@types) {
        *{"$pkg\::$name"} = sub () { $type_class->type_storage->{$name} }
    }
}

{
    package MouseX::Types::Base;
    my %storage;
    sub type_storage {
        $storage{$_[0]} ||= +{}
    }
}

1;

=head1 NAME

Mouse - Organise your Mouse types in libraries

=head1 SYNOPSIS

=head2 Library Definition

  package MyLibrary;

  # predeclare our own types
  use MouseX::Types 
    -declare => [qw(
        PositiveInt NegativeInt
        ArrayRefOfPositiveInt ArrayRefOfAtLeastThreeNegativeInts
        LotsOfInnerConstraints StrOrArrayRef
    )];

  # import builtin types
  use MouseX::Types::Mouse 'Int';

  # type definition.
  subtype PositiveInt, 
      as Int, 
      where { $_ > 0 },
      message { "Int is not larger than 0" };
  
  subtype NegativeInt,
      as Int,
      where { $_ < 0 },
      message { "Int is not smaller than 0" };

  # type coercion
  coerce PositiveInt,
      from Int,
          via { 1 };

  # with parameterized constraints.
  
  subtype ArrayRefOfPositiveInt,
    as ArrayRef[PositiveInt];
    
  subtype ArrayRefOfAtLeastThreeNegativeInts,
    as ArrayRef[NegativeInt],
    where { scalar(@$_) > 2 };

  subtype LotsOfInnerConstraints,
    as ArrayRef[ArrayRef[HashRef[Int]]];
    
  # with TypeConstraint Unions
  
  subtype StrOrArrayRef,
    as Str|ArrayRef;

  1;

=head2 Usage

  package Foo;
  use Mouse;
  use MyLibrary qw( PositiveInt NegativeInt );

  # use the exported constants as type names
  has 'bar',
      isa    => PositiveInt,
      is     => 'rw';
  has 'baz',
      isa    => NegativeInt,
      is     => 'rw';

  sub quux {
      my ($self, $value);

      # test the value
      print "positive\n" if is_PositiveInt($value);
      print "negative\n" if is_NegativeInt($value);

      # coerce the value, NegativeInt doesn't have a coercion
      # helper, since it didn't define any coercions.
      $value = to_PositiveInt($value) or die "Cannot coerce";
  }

  1;

=cut
