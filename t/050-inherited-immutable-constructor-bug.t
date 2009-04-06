#!/usr/bin/perl
use strict;
use warnings;
use Test::More tests => 8;

{
    package Sausage;
    use Mouse::Role;

    has gristle => (is => 'rw');
}

{
    package Dog;
    use Mouse;

    has tail => (is => 'rw');

    __PACKAGE__->meta->make_immutable;
}

{
    package SausageDog;
    use Mouse;
    extends 'Dog';
    with 'Sausage';
    
    has yap => (is => 'rw');

# This class is mutable, but derives from an immutable base, and so
# used to inherit an immutable constructor compiled for the wrong
# class.  It is composed with a Role, and should acquire both the
# attributes in that role, and the initialisers. Likewise for it's own
# attributes. (In the bug this test exhibited, it wasn't acquiring an
# initialiser for 'gristle' or 'yap').
#
# This has now been fixed by adding a check in the immutable
# constructor that the invoking class is the right one, else it
# redispatches to Mouse::Object::new.
}




my $fritz = SausageDog->new(gristle => 1, 
                            tail => 1,
                            yap => 1);


isa_ok $fritz, 'SausageDog';
isa_ok $fritz, 'Dog';
ok !$fritz->isa('Sausage'), "Fritz is not a Sausage";
ok $fritz->does('Sausage'), "Fritz does Sausage";

can_ok $fritz, qw(tail gristle yap);

ok $fritz->gristle, "Fritz has gristle";
ok $fritz->tail, "Fritz has a tail";
ok $fritz->yap, "Fritz has a yap";



