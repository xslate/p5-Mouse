#!/usr/bin/env perl
use strict;
use warnings;
use Test::More tests => 11;
use Mouse::Util ':test';

require Mouse;
use lib 't/lib';

ok(!Mouse::is_class_loaded(), "is_class_loaded with no argument returns false");
ok(!Mouse::is_class_loaded(''), "can't load the empty class");
ok(!Mouse::is_class_loaded(\"foo"), "can't load a class name reference??");

throws_ok { Mouse::load_class()       } qr/Invalid class name \(undef\)/;
throws_ok { Mouse::load_class('')     } qr/Invalid class name \(\)/;
throws_ok { Mouse::load_class(\"foo") } qr/Invalid class name \(SCALAR\(\w+\)\)/;

ok(Mouse::load_class('Anti::Mouse'));
can_ok('Anti::Mouse' => 'antimouse');

do {
    package Class;
    sub yay {}
};

ok(Mouse::load_class('Class'), "this should not die!");

throws_ok {
    Mouse::load_class('FakeClassOhNo');
} qr/Can't locate /;

throws_ok {
    Mouse::load_class('Anti::MouseError');
} qr/Missing right curly/;

