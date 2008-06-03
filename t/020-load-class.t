#!/usr/bin/env perl
use strict;
use warnings;
use Test::More tests => 5;
use Test::Exception;

require Mouse;
use lib 't/lib';

ok(Mouse::load_class('Anti::Mouse'));
can_ok('Anti::Mouse' => 'antimouse');

do {
    package Class;
};

ok(Mouse::load_class('Class'), "this should not die!");

TODO: {
    local $TODO = "can't have the previous test and this test pass.. yet";
    throws_ok {
        Mouse::load_class('FakeClassOhNo');
    } qr/Can't locate /;
};

throws_ok {
    Mouse::load_class('Anti::MouseError');
} qr/Missing right curly/;

