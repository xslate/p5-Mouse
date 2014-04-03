#!/usr/bin/perl
use strict;
use warnings;
use Test::More;
use Test::Exception;

{
    package Boolean;

    sub new
    {
        my $self = shift;
        bless [ shift ], $self;
    }

    use overload (
       "0+"     => sub { shift->[0] ? 1 : 0 },
       fallback => 1,
    );

    package Foo;
    use Mouse;

    has flag => (
        is       => 'ro',
        isa      => 'Bool',
    );

    no Mouse;
}

my $false;
lives_ok {
    $false = Foo->new( flag => Boolean->new(0) );
} 'pseudo false value';
ok( $false && defined $false->flag && !$false->flag, 'false' );

my $true;
lives_ok {
    $true = Foo->new( flag => Boolean->new(1) );
} 'pseudo true value';
ok( $true && defined $false->flag && $true->flag, 'true' );

done_testing;
