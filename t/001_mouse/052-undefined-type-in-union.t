#!perl

use strict;
use warnings;
use Test::More skip_all => 'suspending';
use Test::More;

use Mouse::Util::TypeConstraints;

{
    package Foo;
    use Mouse;

    has my_class => (
        is  => 'rw',
        isa => 'My::New::Class | Str',
    );
}
my $t = Foo->meta->get_attribute('my_class')->type_constraint;

eval q{
    package My::New::Class;
    use Mouse;
    package My::New::DerivedClass;
    use Mouse;
    extends 'My::New::Class';
};

isa_ok $t, 'Mouse::Meta::TypeConstraint';
ok $t->check(My::New::Class->new);
ok $t->check(My::New::DerivedClass->new);
ok $t->check('Foo');
ok!$t->check(undef);
ok!$t->check(bless {}, 'Foo');

done_testing;
