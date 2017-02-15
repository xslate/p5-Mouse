#!/usr/bin/perl
use strict;
use warnings;

use Test::More;

{
    package My::Parent;
    use Mouse;
    sub BUILD {}
}
{
    package My::ChildA;
    use Mouse;
    extends 'My::Parent';
    sub BUILD {}
}
{
    package My::ChildB;
    use Mouse;
    extends 'My::ChildA';
    sub BUILD {}
}

sub fac {
    my $num = $_[0];
    if ($num == 1) {
        My::ChildB->new();
        return 1;
    } else {
        $num * fac($num - 1);
    }
}

is fac(2), 2;

done_testing();
