#!/usr/bin/env perl
use strict;
use warnings;
use Test::More tests => 9;
use Test::Exception;

do {
    package Class;
    use Mouse;

    ::lives_ok {
        has a => (
            is => 'rw',
            default => sub { [1] },
        );
    };

    ::lives_ok {
        has code => (
            is => 'rw',
            default => sub { sub { 1 } },
        );
    };

    ::throws_ok {
        has b => (
            is => 'rw',
            default => [],
        );
    } qr/References are not allowed as default values/;

    ::throws_ok {
        has c => (
            is => 'rw',
            default => {},
        );
    } qr/References are not allowed as default values/;

    ::throws_ok {
        has d => (
            is => 'rw',
            default => Test::Builder->new,
        );
    } qr/References are not allowed as default values/;
};

is(ref(Class->new->code), 'CODE', "default => sub { sub { 1 } } stuffs a coderef");
is(Class->new->code->(), 1, "default => sub sub strips off the first coderef");
is_deeply(Class->new->a, [1], "default of sub { reference } works");

do {
  package Class::Two;
  use Mouse;
  has foo => (is => 'rw', default => sub {
    die unless $_[0]->isa('Class::Two');
    shift->default_foo;
  });
  sub default_foo { 1 };
};

my $obj2 = Class::Two->new;
is($obj2->foo, 1, 'default method gets the $_[0] it needs to work');
