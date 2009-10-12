#!/usr/bin/perl

use strict;
use warnings;

use Test::More tests => 16;
use Test::Exception;



{
    package Foo::Meta::Attribute;
    use Mouse;

    extends 'Mouse::Meta::Attribute';

    around 'new' => sub {
        my $next = shift;
        my $self = shift;
        my $name = shift;
        $next->($self, $name, (is => 'rw', isa => 'Foo'), @_);
    };

    package Foo;
    use Mouse;

    has 'foo' => (metaclass => 'Foo::Meta::Attribute');
}
{
    my $foo = Foo->new;
    isa_ok($foo, 'Foo');

    my $foo_attr = Foo->meta->get_attribute('foo');
    isa_ok($foo_attr, 'Foo::Meta::Attribute');
    isa_ok($foo_attr, 'Mouse::Meta::Attribute');

    is($foo_attr->name, 'foo', '... got the right name for our meta-attribute');
    ok($foo_attr->has_accessor, '... our meta-attrubute created the accessor for us');

    ok($foo_attr->has_type_constraint, '... our meta-attrubute created the type_constraint for us');

    my $foo_attr_type_constraint = $foo_attr->type_constraint;
    isa_ok($foo_attr_type_constraint, 'Mouse::Meta::TypeConstraint');

    is($foo_attr_type_constraint->name, 'Foo', '... got the right type constraint name');

    local $TODO = '$type_constraint->parent is not reliable';
    is($foo_attr_type_constraint->parent, 'Object', '... got the right type constraint parent name');
}
{
    package Bar::Meta::Attribute;
    use Mouse;

    #extends 'Class::MOP::Attribute';
    extends 'Foo::Meta::Attribute';

    package Bar;
    use Mouse;

    ::lives_ok {
        has 'bar' => (metaclass => 'Bar::Meta::Attribute');
    } '... the attribute metaclass need not be a Mouse::Meta::Attribute as long as it behaves';
}

{
    package Mouse::Meta::Attribute::Custom::Foo;
    sub register_implementation { 'Foo::Meta::Attribute' }

    package Mouse::Meta::Attribute::Custom::Bar;
    use Mouse;

    extends 'Mouse::Meta::Attribute';

    package Another::Foo;
    use Mouse;

    ::lives_ok {
        has 'foo' => (metaclass => 'Foo');
    } '... the attribute metaclass alias worked correctly';

    ::lives_ok {
        has 'bar' => (metaclass => 'Bar', is => 'bare');
    } '... the attribute metaclass alias worked correctly';
}

{
    my $foo_attr = Another::Foo->meta->get_attribute('foo');
    isa_ok($foo_attr, 'Foo::Meta::Attribute');
    isa_ok($foo_attr, 'Mouse::Meta::Attribute');

    my $bar_attr = Another::Foo->meta->get_attribute('bar');
    isa_ok($bar_attr, 'Mouse::Meta::Attribute::Custom::Bar');
    isa_ok($bar_attr, 'Mouse::Meta::Attribute');
}


