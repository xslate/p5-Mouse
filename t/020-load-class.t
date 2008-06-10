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
    sub yay {}
};

ok(Mouse::load_class('Class'), "this should not die!");

throws_ok {
    Mouse::load_class('FakeClassOhNo');
} qr/Can't locate /;

throws_ok {
    Mouse::load_class('Anti::MouseError');
} qr/Missing right curly/;

