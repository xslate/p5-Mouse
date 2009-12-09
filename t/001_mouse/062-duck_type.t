#!perl
use strict;
use warnings;

use Test::More tests => 15;

use Mouse::Util::TypeConstraints qw(duck_type);

{
    package Foo;
    use Mouse;

    sub a {}

    package Bar;
    use Mouse;

    extends qw(Foo);

    sub b {}

    package Baz;
    use Mouse;

    sub can {
        my($class, $method) = @_;
        return $method eq 'b';
    }
}

my $CanA   = duck_type CanA => qw(a);
my $CanB  = duck_type CanB => [qw(b)];
my $CanAB = duck_type [qw(a b)];

is $CanA->name, 'CanA';
is $CanB->name, 'CanB';
is $CanAB->name, '__ANON__';

ok $CanA->check(Foo->new);
ok $CanA->check(Bar->new);
ok!$CanA->check(Baz->new);

ok!$CanB->check(Foo->new);
ok $CanB->check(Bar->new);
ok $CanB->check(Baz->new);

ok!$CanAB->check(Foo->new);
ok $CanAB->check(Bar->new);
ok!$CanAB->check(Baz->new);

ok!$CanA->check(undef);
ok!$CanA->check(1);
ok!$CanA->check({});
