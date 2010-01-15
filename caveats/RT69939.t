#!perl -w
# See the CAVEATS section in Mouse.pm
use strict;
use Test::More;

{
    package Class;
    use Mouse;

    has foo => (
        is  => 'rw',

        default => sub{
            # Ticket #69939
            # See the Mouse manpage

            #eval       'BEGIN{ die }';   # NG
            eval{ eval 'BEGIN{ die }' }; # OK
            ::pass 'in a default callback';
        },
    );
}

pass "class definition has been done";

isa_ok(Class->new, 'Class');

done_testing;

