#!perl
#https://rt.cpan.org/Ticket/Display.html?id=61906
use strict;
use warnings;
use Test::More;

package MouseObj;
use Mouse;

has 'only_accessor' => (
   is  => 'rw',
   isa => 'Int',
   accessor => 'only_accessor_accessor',
);

has 'accesor_and_writer' => (
   is  => 'rw',
   isa => 'Int',
   accessor => 'accesor_and_writer_accessor',
   writer   => 'accesor_and_writer_writer',
);

has 'not_with_is' => (
   isa => 'Int',
   accessor => 'not_with_is_accessor',
);

package main;

can_ok('MouseObj', 'only_accessor_accessor');
can_ok('MouseObj', 'accesor_and_writer_accessor');
can_ok('MouseObj', 'accesor_and_writer_writer');
can_ok('MouseObj', 'not_with_is_accessor');

done_testing;
