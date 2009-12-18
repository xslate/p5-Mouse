#!perl
use strict;
use warnings;

use Test::More tests => 10;

{
    package OtherClass;
    sub method {}

    package Class;
    use Mouse;

    # this attribute definition is intended to load submodules

    has foo => (
        is => 'rw',
        isa => 'OtherClass',
        handles => qr/./,
    );

    __PACKAGE__->meta->make_immutable; # ensure metaclasses loaded

    package Role;
    use Mouse::Role;

    sub bar {}
}

{
    my $metaclass = Class->meta;

    can_ok($metaclass, 'meta');

    can_ok($metaclass->constructor_class, 'meta');
    can_ok($metaclass->destructor_class, 'meta');
    can_ok($metaclass->attribute_metaclass, 'meta');

    can_ok($metaclass->get_method('foo'),   'meta');
    can_ok($metaclass->get_attribute('foo'), 'meta');
    can_ok($metaclass->get_attribute('foo')->accessor_metaclass, 'meta');
    can_ok($metaclass->get_attribute('foo')->delegation_metaclass, 'meta');
}

{
    my $metarole = Class->meta;

    can_ok($metarole, 'meta');

    can_ok($metarole->get_method('foo'),   'meta');
}
