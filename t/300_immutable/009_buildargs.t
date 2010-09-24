#!/usr/bin/perl

use strict;
use warnings;

use Test::More tests => 14;

{
    package Foo;
    use Mouse;

    has bar => ( is => "rw" );
    has baz => ( is => "rw" );    

    sub BUILDARGS {
        my ( $self, @args ) = @_;
        unshift @args, "bar" if @args % 2 == 1;
        return {@args};
    }

    __PACKAGE__->meta->make_immutable;

    package Bar;
    use Mouse;

    extends qw(Foo);
    
    __PACKAGE__->meta->make_immutable;
}

foreach my $class qw(Foo Bar) {
    is( $class->new->bar, undef, "no args" );
    is( $class->new( bar => 42 )->bar, 42, "normal args" );
    is( $class->new( 37 )->bar, 37, "single arg" );
    my $o = $class->new(bar => 42, baz => 47);
    is($o->bar, 42, '... got the right bar');
    is($o->baz, 47, '... got the right bar');
    my $ob = $class->new(42, baz => 47);
    is($ob->bar, 42, '... got the right bar');
    is($ob->baz, 47, '... got the right bar');
}


