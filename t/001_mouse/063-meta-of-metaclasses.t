#!perl
use strict;
use warnings;

use Test::More tests => 6;

use Mouse ();

can_ok('Mouse::Meta::Class', 'meta');
can_ok('Mouse::Meta::Role', 'meta');

my $meta = Mouse::Meta::Class->meta;
can_ok($meta->constructor_class, 'meta');
can_ok($meta->destructor_class, 'meta');
can_ok($meta->attribute_metaclass, 'meta');

can_ok($meta->get_method('is_anon_class'), 'meta');

