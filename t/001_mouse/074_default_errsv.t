#!perl
# https://rt.cpan.org/Ticket/Display.html?id=77227
use strict;

use Test::More;
if($] < 5.014) {
    plan( skip_all => 'Perl 5.14 is required for this test' );
}
else {
    plan( tests => 1 );

    {
        package Foo;
        use Mouse;
        has e => (
            is => 'ro',
            default => sub { $@ },
        );
    }

    $@ = "foo";
    my $Foo = Foo->new;
    is $Foo->e, "foo";
}

done_testing;

