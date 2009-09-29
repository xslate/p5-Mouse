#!perl

use strict;
use warnings;
use Test::More tests => 5;

use Mouse::Util::TypeConstraints;

my $z = Mouse::Util::TypeConstraints::find_or_create_isa_type_constraint('My::New::Class | Str');

#diag $z->dump;

eval q{
    package My::New::Class;
    use Mouse;
    package My::New::DerivedClass;
    use Mouse;
    extends 'My::New::Class';
};

ok $z->check(My::New::Class->new);
ok $z->check(My::New::DerivedClass->new);
ok $z->check('Foo');
ok!$z->check(undef);
ok!$z->check(bless {}, 'Foo');

