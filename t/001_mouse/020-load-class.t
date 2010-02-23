#!/usr/bin/env perl
use strict;
use warnings;
use Test::More;
use Test::Exception;

require Mouse;
use lib 't/lib';

lives_and {
    ok(!Mouse::is_class_loaded(undef),  "is_class_loaded with undef returns false");
    ok(!Mouse::is_class_loaded(''),     "can't load the empty class");
    ok(!Mouse::is_class_loaded(\"foo"), "can't load a class name reference");

    ok(Mouse::is_class_loaded("Mouse"),      "Mouse is loaded");
    ok(Mouse::is_class_loaded("Test::More"), "Test::More is loaded");
};

throws_ok { Mouse::load_class(undef)  } qr/Invalid class name \(undef\)/;
throws_ok { Mouse::load_class('')     } qr/Invalid class name \(\)/;
throws_ok { Mouse::load_class(\"foo") } qr/Invalid class name \(SCALAR\(\w+\)\)/;

throws_ok { Mouse::load_class("Foo!") }        qr/Invalid class name/;
throws_ok { Mouse::load_class("Foo::Bar42!") } qr/Invalid class name/;

ok(Mouse::load_class('Unsweetened'));
can_ok('Unsweetened' => 'unsweetened');

do {
    package Class;
    sub yay {}
};

ok(Mouse::load_class('Class'), "this should not die!");

throws_ok {
    Mouse::load_class('FakeClassOhNo');
} qr/Can't locate /;

throws_ok {
    Mouse::load_class('SyntaxError');
} qr/Missing right curly/;

done_testing;
