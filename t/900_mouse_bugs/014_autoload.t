#!/usr/bin/env perl
# https://gist.github.com/3414679

use strict;
use warnings;
use Test::More;

{
    package Base;
    use base qw/Class::Accessor::Fast/;
    __PACKAGE__->mk_accessors( qw/name/ );
    sub new {
        my ( $class, %opts ) = @_;
        bless { %opts }, $class;
    }
}

{
    package AutoloadedBase;
    use base qw/Class::Accessor::Fast/;
    __PACKAGE__->mk_accessors( qw/name/ );
    sub new {
        my ( $class, %opts ) = @_;
        bless { %opts }, $class;
    }

    our $AUTOLOAD;
    sub AUTOLOAD {
        my $self = shift;
        ::note "called $AUTOLOAD";
        0;
    }

    sub can {
        my($self, $method)  = @_;
        return $self->SUPER::can($method);
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
    use MouseX::Foreign qw/AutoloadedBase/;
}

my $b = AutoloadedSuper->new( name => 'b' );

Tester->meta->apply( $b );
is( $b->test, 'b' );

done_testing;

