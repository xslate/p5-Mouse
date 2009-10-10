package Foo;
use strict;
use warnings;
use Test::More tests => 1;
use Mouse;

is $INC{'Test/Exception.pm'}, undef, "don't load Test::Exception on production environment";
