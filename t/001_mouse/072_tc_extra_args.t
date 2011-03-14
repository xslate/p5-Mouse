#!perl
use strict;
use Test::More tests => 2;
use if 'Mouse' ne 'Mo' . 'use', 'Test::More', skip_all => 'Mouse only';
use Mouse::Meta::TypeConstraint;

my @args;
my $tc = Mouse::Meta::TypeConstraint->new(
    constraint => sub {
        is_deeply \@args, \@_;
    },
);

@args = qw(foo bar baz);
$tc->check( @args );

@args = (100, 200);
$tc->check( @args );

done_testing;
