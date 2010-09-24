use strict;
use warnings;

use Test::More tests => 1;

use Mouse::Util::TypeConstraints;


eval { Mouse::Util::TypeConstraints::create_type_constraint_union() };

like( $@, qr/\QYou must pass in at least 2 type names to make a union/,
      'can throw a proper error without Mouse being loaded by the caller' );
