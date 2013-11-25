#!perl -T
package Foo;
use strict;
use warnings;
use Test::More tests => 2;

require_ok 'Mouse';
require_ok 'Mouse::Role';

no warnings 'uninitialized';

my $xs = !exists( $INC{'Mouse/PurePerl.pm'} );

diag "Testing Mouse/$Mouse::VERSION (", $xs ? 'XS' : 'Pure Perl', ")";
eval { diag "XS state: " . ( Mouse::Util::MOUSE_XS() ? 'true' : 'false' ); };
diag $@ if $@;
diag "ENV<PERL_ONLY>: " . ( $ENV{PERL_ONLY} ? 'true' : 'false' );
diag "";

diag "Soft dependency versions:";

eval { require Moose };
diag "    Class::MOP: $Class::MOP::VERSION";
diag "    Moose: $Moose::VERSION";

