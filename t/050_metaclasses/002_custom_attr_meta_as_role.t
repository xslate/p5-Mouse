#!/usr/bin/perl

use strict;
use warnings;

use Test::More tests => 2;
use Test::Exception;

;

lives_ok {
    package MouseX::Attribute::Test;
    use Mouse::Role;
} 'creating custom attribute "metarole" is okay';

lives_ok {
    package Mouse::Meta::Attribute::Custom::Test;
    use Mouse;

    extends 'Mouse::Meta::Attribute';
    with 'MouseX::Attribute::Test';
} 'custom attribute metaclass extending role is okay';
