#!/usr/bin/perl

use strict;
use warnings;

use Test::More tests => 24;
use Test::Exception;

{

    package Foo;
    use Mouse;

    has foo => ( is => "ro" );

    package Bar;
    use metaclass (
        metaclass   => "Mouse::Meta::Class",
        error_class => "Mouse::Error::Croak",
    );
    use Mouse;

    has foo => ( is => "ro" );

    package Baz::Error;
    use Mouse;

    has message    => ( isa => "Str",                    is => "ro" );
    has attr       => ( isa => "Mouse::Meta::Attribute", is => "ro" );
    has method     => ( isa => "Mouse::Meta::Method",    is => "ro" );
    has metaclass  => ( isa => "Mouse::Meta::Class",     is => "ro" );
    has data       => ( is  => "ro" );
    has line       => ( isa => "Int",                    is => "ro" );
    has file       => ( isa => "Str",                    is => "ro" );
    has last_error => ( isa => "Any",                    is => "ro" );

    package Baz;
    use metaclass (
        metaclass   => "Mouse::Meta::Class",
        error_class => "Baz::Error",
    );
    use Mouse;

    has foo => ( is => "ro" );
}

my $line;
sub blah { $line = __LINE__; shift->foo(4) }

sub create_error {
    eval {
        eval { die "Blah" };
        blah(shift);
    };
    ok( my $e = $@, "got some error" );
    return {
        file  => __FILE__,
        line  => $line,
        error => $e,
    };
}

{
    my $e = create_error( Foo->new );
    ok( !ref( $e->{error} ), "error is a string" );
    like( $e->{error}, qr/line $e->{line}\n.*\n/s, "confess" );
}

{
    my $e = create_error( Bar->new );
    ok( !ref( $e->{error} ), "error is a string" );
    like( $e->{error}, qr/line $e->{line}$/s, "croak" );
}

{
    my $e = create_error( my $baz = Baz->new );
    isa_ok( $e->{error}, "Baz::Error" );
    unlike( $e->{error}->message, qr/line $e->{line}/s,
        "no line info, just a message" );
    isa_ok( $e->{error}->metaclass, "Mouse::Meta::Class", "metaclass" );
    is( $e->{error}->metaclass, Baz->meta, "metaclass value" );
    isa_ok( $e->{error}->attr, "Mouse::Meta::Attribute", "attr" );
    is( $e->{error}->attr, Baz->meta->get_attribute("foo"), "attr value" );
    isa_ok( $e->{error}->method, "Mouse::Meta::Method", "method" );
    is( $e->{error}->method, Baz->meta->get_method("foo"), "method value" );
    is( $e->{error}->line,   $e->{line},                   "line attr" );
    is( $e->{error}->file,   $e->{file},                   "file attr" );
    is_deeply( $e->{error}->data, [ $baz, 4 ], "captured args" );
    like( $e->{error}->last_error, qr/Blah/, "last error preserved" );
}

{
    package Role::Foo;
    use Mouse::Role;

    sub foo { }
}

{
    package Baz::Sub;

    use Mouse;
    extends 'Baz';

    Mouse::Util::MetaRole::apply_metaclass_roles(
        for_class       => __PACKAGE__,
        metaclass_roles => ['Role::Foo'],
    );
}

{
    package Baz::Sub::Sub;
    use metaclass (
        metaclass   => 'Mouse::Meta::Class',
        error_class => 'Mouse::Error::Croak',
    );
    use Mouse;

    ::dies_ok { extends 'Baz::Sub' } 'error_class is included in metaclass compatibility checks';
}

{
    package Foo::Sub;

    use metaclass (
        metaclass   => 'Mouse::Meta::Class',
        error_class => 'Mouse::Error::Croak',
    );

    use Mouse;

    Mouse::Util::MetaRole::apply_metaclass_roles(
        for_class         => __PACKAGE__,
        metaclass_roles => ['Role::Foo'],
    );
}

ok( Foo::Sub->meta->error_class->isa('Mouse::Error::Croak'),
    q{Foo::Sub's error_class still isa Mouse::Error::Croak} );

{
    package Foo::Sub::Sub;
    use Mouse;

    ::lives_ok { extends 'Foo::Sub' } 'error_class differs by role so incompat is handled';

    Mouse::Util::MetaRole::apply_metaclass_roles(
        for_class         => __PACKAGE__,
        error_class_roles => ['Role::Foo'],
    );
}

ok( Foo::Sub::Sub->meta->error_class->meta->does_role('Role::Foo'),
    q{Foo::Sub::Sub's error_class does Role::Foo} );
ok( Foo::Sub::Sub->meta->error_class->isa('Mouse::Error::Croak'),
    q{Foo::Sub::Sub's error_class now subclasses Mouse::Error::Croak} );
