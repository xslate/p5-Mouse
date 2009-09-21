#!/usr/bin/perl
use strict;
use warnings;

use Test::More tests => 2;
use Test::Exception;

{
    package Bomb;
    use Mouse::Role;

    sub fuse { }
    sub explode { }

    package Spouse;
    use Mouse::Role;

    sub fuse { }
    sub explode { }

    package Caninish;
    use Mouse::Role;

    sub bark { }

    package Treeve;
    use Mouse::Role;

    sub bark { }
}

package PracticalJoke;
use Mouse;

::throws_ok {
    with 'Bomb', 'Spouse';
} qr/Due to method name conflicts in roles 'Bomb' and 'Spouse', the methods 'explode' and 'fuse' must be implemented or excluded by 'PracticalJoke'/;

::throws_ok {
    with (
        'Bomb', 'Spouse',
        'Caninish', 'Treeve',
    );
} qr/Due to a method name conflict in roles 'Caninish' and 'Treeve', the method 'bark' must be implemented or excluded by 'PracticalJoke'/;

