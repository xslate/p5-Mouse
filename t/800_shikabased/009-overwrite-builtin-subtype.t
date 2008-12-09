use strict;
use warnings;
use Test::More tests => 1;

eval {
    package Request;
    use Mouse::TypeRegistry;

    subtype 'Int' => where { 1};
};
like $@, qr/The type constraint 'Int' has already been created, cannot be created again in Request/;
