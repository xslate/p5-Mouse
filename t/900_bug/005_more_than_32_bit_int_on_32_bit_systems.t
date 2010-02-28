package MyInteger;
use Mouse;

has a_int => (
    is => 'rw',
    isa => 'Int',
);

has a_num => (
    is => 'rw',
    isa => 'Num',
);

package main;
use Test::More tests => 212 * 2;

for (my $i = 1; $i <= 10e100; $i += $i * 2) {
    my $int = MyInteger->new( a_int => $i )->a_int;
    cmp_ok($int, '==', $i, "Mouse groked the Int $i");

    my $num = MyInteger->new( a_num => $i )->a_num;
    cmp_ok($num, '==', $i, "Mouse groked the Num $i");
}
