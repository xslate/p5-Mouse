use strict;
use warnings;
use Test::More tests => 1;

eval {
    package Request;
    use Mouse::Util::TypeConstraints;

    type 'Int' => where { 1};
};
like $@, qr/The type constraint 'Int' has already been created in Mouse::Util::TypeConstraints and cannot be created again in Request/;
