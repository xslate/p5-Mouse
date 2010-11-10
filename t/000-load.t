#!perl -T
package Foo;
use strict;
use warnings;
use Test::More tests => 2;

require_ok 'Mouse';
require_ok 'Mouse::Role';

no warnings 'uninitialized';

my $xs = !exists( $INC{'Mouse/PuprePerl.pm'} );

diag "Testing Mouse/$Mouse::VERSION (", $xs ? 'XS' : 'Pure Perl', ")";

diag "Soft dependency versions:";

eval { require Moose };
diag "    Class::MOP: $Class::MOP::VERSION";
diag "    Moose: $Moose::VERSION";

if($xs) { # display info for CPAN testers
    if(open my $in, '<', 'Makefile') {
        diag 'xsubpp settings:';
        while(<$in>) {
            if(/^XSUBPP/) {
                diag $_;
            }
        }
    }
}

