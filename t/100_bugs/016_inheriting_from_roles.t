#!/usr/bin/perl

use strict;
use warnings;

use Test::More tests => 1;
use Test::Exception;



{
    package My::Role;
    use Mouse::Role;
}
{
    package My::Class;
    use Mouse;

    ::throws_ok {
        extends 'My::Role';
    } qr/You cannot inherit from a Mouse Role \(My\:\:Role\)/,
    '... this croaks correctly';
}
