#!/usr/bin/env perl
use strict;
use warnings;
use Test::More tests => 1;
use Test::Exception;

TODO: {
    local $TODO = "Mouse does not support parameterized types yet";

    eval {
        package Foo;
        use Mouse;

        has foo => (
            is  => 'ro',
            isa => 'HashRef[Int]',
        );
    };

    ok(Foo->meta->has_attribute('foo'));
};

