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
            # Those eval()s which try to load missing modules in
            # compile-time triggers a Perl bug (Ticket #69939).
            # This is related not only to Mouse, but also to tie-modules.

            #eval 'use MayNotBeInstalled';              # NG
            #eval 'BEGIN{ require MayNotBeInstalled }'; # NG
            eval{ eval 'use MayNotBeInstalled' };       # OK
            ::pass 'in a default callback';
        },
    );
}

pass "class definition has been done";

isa_ok(Class->new, 'Class');

done_testing;

