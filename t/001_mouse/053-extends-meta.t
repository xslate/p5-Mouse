#!/usr/bin/env perl
use strict;
use warnings;
use Test::More tests => 14;
use Test::Exception;
{
    package My::Meta::Class;
    use Mouse;
    extends 'Mouse::Meta::Class';

    has my_class_attr => (
        is      => 'rw',
        default => 42,
    );
    package My::Meta::Role;
    use Mouse;
    extends 'Mouse::Meta::Role';

    has my_role_attr => (
        is      => 'rw',
        default => 43,
    );
    package My::Meta::Attribute;
    use Mouse;
    extends 'Mouse::Meta::Attribute';

    has my_attr_attr => (
        is      => 'rw',
        default => 44,
    );
}

my $meta = My::Meta::Class->initialize('Foo');
isa_ok $meta, 'My::Meta::Class';
isa_ok $meta->meta, 'Mouse::Meta::Class';
can_ok $meta, qw(name my_class_attr);
is $meta->name, 'Foo';
lives_and{
    is $meta->my_class_attr, 42;
};

$meta = My::Meta::Role->initialize('Bar');
isa_ok $meta, 'My::Meta::Role';
isa_ok $meta->meta, 'Mouse::Meta::Class';
can_ok $meta, qw(name my_role_attr);
is $meta->name, 'Bar';
lives_and{
    is $meta->my_role_attr, 43;
};

$meta = My::Meta::Attribute->new('baz');
isa_ok $meta, 'My::Meta::Attribute';
can_ok $meta, qw(name my_attr_attr);
is $meta->name, 'baz';
lives_and{
    is $meta->my_attr_attr, 44;
};

