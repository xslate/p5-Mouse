#!/usr/bin/env perl
# https://gist.github.com/3414679

use strict;
use warnings;
use Test::More;

{
    package AutoloadedBase;
    use Mouse;

    has name => (
        is => 'rw',
    );

    our $AUTOLOAD;
    sub AUTOLOAD {
        my $self = shift;
        ::note "called $AUTOLOAD";
        0;
    }
}

{
    package Tester;
    use Mouse::Role;
    sub test {
        return shift->name;
    }
}

{
    package AutoloadedSuper;
    use Mouse;
    extends qw/AutoloadedBase/;
}

my $b = AutoloadedSuper->new( name => 'b' );

Tester->meta->apply( $b );
is( $b->test, 'b' );

done_testing;

