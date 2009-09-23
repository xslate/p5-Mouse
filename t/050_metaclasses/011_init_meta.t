#!/usr/bin/perl

use strict;
use warnings;

use Test::More tests => 4;

use Mouse ();

my $meta = Mouse->init_meta(for_class => 'Foo');

ok( Foo->isa('Mouse::Object'), '... Foo isa Mouse::Object');
isa_ok( $meta, 'Mouse::Meta::Class' );
isa_ok( Foo->meta, 'Mouse::Meta::Class' );

is($meta, Foo->meta, '... our metas are the same');
