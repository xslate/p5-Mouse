#!/usr/bin/env perl
use strict;
use warnings;
use Test::More tests => 11;
use Test::Exception;

require Mouse;
use lib 't/lib';

for my $method ('load_class', 'is_class_loaded') {
    my $code = Mouse->can($method);
    ok(!$code->(), "$method with no argument returns false");
    ok(!$code->(''), "can't load the empty class");
    ok(!$code->(\"foo"), "can't load a class name reference??");
}

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

