#!/usr/bin/perl
use strict;
use warnings;
use Test::More tests => 3;

BEGIN{
    $SIG{__WARN__} = sub { $_[0] =~ /deprecated/ or warn @_ };

    package Foo;
    use Mouse;

    sub import{
        shift;
        Mouse->export_to_level(1, @_);
    }
    $INC{'Foo.pm'}++;
}

package A;
use Test::More;

use Foo qw(has);

ok defined(&has), "export_to_level (DEPRECATED)";


ok!defined(&Bar::has), "export (DEPRECATED)";
Mouse->export('Bar', 'has');
ok defined(&Bar::has), "export (DEPRECATED)";
