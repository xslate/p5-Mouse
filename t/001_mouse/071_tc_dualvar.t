#!perl -w
use strict;
use Test::More;
use Errno qw(ENOENT EPERM);
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

for my $e(ENOENT, EPERM) {
    $! = $e;
    eval { $foo->intval($!) };
    like $@, qr/Validation failed for 'Int'/, 'Int for dualvar';

    $! = $e;
    eval { $foo->numval($!) };
    like $@, qr/Validation failed for 'Num'/, 'Num for dualvar';
}
done_testing;

