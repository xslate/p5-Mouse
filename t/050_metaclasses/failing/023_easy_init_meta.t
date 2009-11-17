#!/usr/bin/perl

use strict;
use warnings;

use Test::More tests => 13;
use Test::Mouse qw(does_ok);

{
    package Foo::Trait::Class;
    use Mouse::Role;
}

{
    package Foo::Trait::Attribute;
    use Mouse::Role;
}

{
    package Foo::Role::Base;
    use Mouse::Role;
}

{
    package Foo::Exporter;
    use Mouse::Exporter;

    Mouse::Exporter->setup_import_methods(
        metaclass_roles           => ['Foo::Trait::Class'],
        attribute_metaclass_roles => ['Foo::Trait::Attribute'],
        base_class_roles          => ['Foo::Role::Base'],
    );
}

{
    package Foo;
    use Mouse;
    Foo::Exporter->import;

    has foo => (is => 'ro');

    ::does_ok(Foo->meta, 'Foo::Trait::Class');
    ::does_ok(Foo->meta->get_attribute('foo'), 'Foo::Trait::Attribute');
    ::does_ok('Foo', 'Foo::Role::Base');
}

{
    package Foo::Exporter::WithMouse;
    use Mouse ();
    use Mouse::Exporter;

    my ($import, $unimport, $init_meta) =
        Mouse::Exporter->build_import_methods(
            also                      => 'Mouse',
            metaclass_roles           => ['Foo::Trait::Class'],
            attribute_metaclass_roles => ['Foo::Trait::Attribute'],
            base_class_roles          => ['Foo::Role::Base'],
            install                   => [qw(import unimport)],
        );

    sub init_meta {
        my $package = shift;
        my %options = @_;
        ::pass('custom init_meta was called');
        Mouse->init_meta(%options);
        return $package->$init_meta(%options);
    }
}

{
    package Foo2;
    Foo::Exporter::WithMouse->import;

    has(foo => (is => 'ro'));

    ::isa_ok('Foo2', 'Mouse::Object');
    ::isa_ok(Foo2->meta, 'Mouse::Meta::Class');
    ::does_ok(Foo2->meta, 'Foo::Trait::Class');
    ::does_ok(Foo2->meta->get_attribute('foo'), 'Foo::Trait::Attribute');
    ::does_ok('Foo2', 'Foo::Role::Base');
}

{
    package Foo::Role;
    use Mouse::Role;
    Foo::Exporter->import;

    ::does_ok(Foo::Role->meta, 'Foo::Trait::Class');
}

{
    package Foo::Exporter::WithMouseRole;
    use Mouse::Role ();
    use Mouse::Exporter;

    my ($import, $unimport, $init_meta) =
        Mouse::Exporter->build_import_methods(
            also                      => 'Mouse::Role',
            metaclass_roles           => ['Foo::Trait::Class'],
            attribute_metaclass_roles => ['Foo::Trait::Attribute'],
            base_class_roles          => ['Foo::Role::Base'],
            install                   => [qw(import unimport)],
        );

    sub init_meta {
        my $package = shift;
        my %options = @_;
        ::pass('custom init_meta was called');
        Mouse::Role->init_meta(%options);
        return $package->$init_meta(%options);
    }
}

{
    package Foo2::Role;
    Foo::Exporter::WithMouseRole->import;

    ::isa_ok(Foo2::Role->meta, 'Mouse::Meta::Role');
    ::does_ok(Foo2::Role->meta, 'Foo::Trait::Class');
}
