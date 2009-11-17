#!perl
use strict;
use warnings;
use Test::More tests => 6;

{
    package MyClass;
    use Mouse;

    has lazy_weak_with_default => (
        is       => 'rw',
        isa      => 'Ref',
        weak_ref => 1,
        lazy     => 1,
        default  => sub{ [] },
    );

    has weak_with_default => (
        is       => 'rw',
        isa      => 'Ref',
        weak_ref => 1,
        default  => sub{ [] },
    );

}

my $o = MyClass->new();
is($o->weak_with_default, undef);
is($o->lazy_weak_with_default, undef);
is($o->lazy_weak_with_default, undef);

MyClass->meta->make_immutable();

$o = MyClass->new();
is($o->weak_with_default, undef);
is($o->lazy_weak_with_default, undef);
is($o->lazy_weak_with_default, undef);
