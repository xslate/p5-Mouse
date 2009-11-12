#!/usr/bin/env perl
use strict;
use warnings;
use Test::More tests => 11;
use Test::Exception;

{
    package C;
    use Mouse;
}

# original BUILDARGS

is_deeply( C->BUILDARGS(), {} );
is_deeply( C->BUILDARGS(foo => 42), {foo => 42} );
is_deeply( C->BUILDARGS(foo => 42, foo => 'bar'), {foo => 'bar'} );
is_deeply( C->BUILDARGS({foo => 1, bar => 2}), {foo => 1, bar => 2} );

my %hash = (foo => 10);
my $args = C->BUILDARGS(\%hash);
$args->{foo}++;
is $hash{foo}, 10, 'values must be copied';

%hash = (foo => 10);
$args = C->BUILDARGS(%hash);
$args->{foo}++;
is $hash{foo}, 10, 'values must be copied';

throws_ok {
    C->BUILDARGS([]);
} qr/must be a HASH ref/;


throws_ok {
    C->BUILDARGS([]);
} qr/must be a HASH ref/;


# custom BUILDARGS

do {
    package Foo;
    use Mouse;

    has foo => ( is => "rw" );

    sub BUILDARGS {
        my ( $self, @args ) = @_;
        return { @args % 2 ? ( foo => @args ) : @args };
    }
};

is(Foo->new->foo, undef, "no value");
is(Foo->new("bar")->foo, "bar", "single arg");
is(Foo->new(foo => "bar")->foo, "bar", "twoargs");

