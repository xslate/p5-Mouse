# See also http://rt.cpan.org/Public/Bug/Display.html?id=55048
use strict;
use Test::More tests => 24;

{
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
}

foreach my $i(2**32, 2**40, 2**46) {
    for my $sig(1, -1) {
        my $value = $i * $sig;

        my $int = MyInteger->new( a_int => $value )->a_int;
        cmp_ok($int, '==', $value, "Mouse groked the Int $i");


        my $num = MyInteger->new( a_num => $value )->a_num;
        cmp_ok($num, '==', $value, "Mouse groked the Num $i");

        $value += 0.5;

        eval { MyInteger->new( a_int => $value ) };
        like $@, qr/does not pass the type constraint/, "Mouse does not regard $value as Int";
        eval { MyInteger->new( a_num => $value ) };
        is $@, '', "Mouse regards $value as Num";
    }
}

