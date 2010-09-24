#!/usr/bin/perl

use strict;
use warnings;

use Test::More tests => 7;
use Test::Exception;



BEGIN {
    package MyFramework::Base;
    use Mouse;

    package MyFramework::Meta::Base;
    use Mouse;

    extends 'Mouse::Meta::Class';

    package MyFramework;
    use Mouse;

    sub import {
        my $CALLER = caller();

        strict->import;
        warnings->import;

        return if $CALLER eq 'main';
        Mouse::init_meta( $CALLER, 'MyFramework::Base', 'MyFramework::Meta::Base' );
        Mouse->import({ into => $CALLER });

        return 1;
    }
}

{
    package MyClass;
    BEGIN { MyFramework->import }

    has 'foo' => (is => 'rw');
}

can_ok( 'MyClass', 'meta' );

isa_ok(MyClass->meta, 'MyFramework::Meta::Base');
isa_ok(MyClass->meta, 'Mouse::Meta::Class');

my $obj = MyClass->new(foo => 10);
isa_ok($obj, 'MyClass');
isa_ok($obj, 'MyFramework::Base');
isa_ok($obj, 'Mouse::Object');

is($obj->foo, 10, '... got the right value');




