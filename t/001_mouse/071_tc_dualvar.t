#!perl -w
use strict;
use Test::More;
use Scalar::Util qw(dualvar);
{
    package Foo;
    use Mouse;
    has intval => (
        is  => 'rw',
        isa => 'Int',
    );
    has numval => (
        is  => 'rw',
        isa => 'Num',
    );
}

my $foo = Foo->new();

my $dv = dualvar(42, 'foo');
eval { $foo->intval($dv) };
like $@, qr/Validation failed for 'Int'/, 'Int for dualvar';

eval { $foo->numval($dv) };
like $@, qr/Validation failed for 'Num'/, 'Num for dualvar';

cmp_ok $dv, 'eq', 'foo';
cmp_ok $dv, '==', 42, 'keeps dualvar-ness';

done_testing;

