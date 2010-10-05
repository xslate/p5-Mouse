#!perl
# https://rt.cpan.org/Public/Bug/Display.html?id=61852
use strict;
use warnings;
use Test::More;
{
 package X;
 use Mouse;
 use Mouse::Util::TypeConstraints;

 subtype 'List'
      => as 'ArrayRef[Any]'
      => where {
       foreach my $item(@{$_}) {
        defined($item) or return 0;
       }
       return 1;
      };

 has 'list' => (
  is  => 'ro',
  isa => 'List',
 );
}

eval { X->new(list => [ 1, 2, 3 ]) };
is $@, '';

eval { X->new(list => [ 1, undef, 3 ]) };
like $@, qr/Validation[ ]failed[ ]for[ ]'List'/xms;
done_testing;
