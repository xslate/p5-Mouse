#!/usr/bin/perl

use strict;
use warnings;

use Test::More;
use Test::Exception;
BEGIN {
    eval "use Test::Output;";
    plan skip_all => "Test::Output is required for this test" if $@;
    plan tests => 65;
}


{
    package HasOwnImmutable;

    use Mouse;

    no Mouse;

    ::stderr_is( sub { eval q[sub make_immutable { return 'foo' }] },
                  '',
                  'no warning when defining our own make_immutable sub' );
}

{
    is( HasOwnImmutable->make_immutable(), 'foo',
        'HasOwnImmutable->make_immutable does not get overwritten' );
}

{
    package MouseX::Empty;

    use Mouse ();
    Mouse::Exporter->setup_import_methods( also => 'Mouse' );
}

{
    package WantsMouse;

    MouseX::Empty->import();

    sub foo { 1 }

    ::can_ok( 'WantsMouse', 'has' );
    ::can_ok( 'WantsMouse', 'with' );
    ::can_ok( 'WantsMouse', 'foo' );

    MouseX::Empty->unimport();
}

{
    # Note: it's important that these methods be out of scope _now_,
    # after unimport was called. We tried a
    # namespace::clean(0.08)-based solution, but had to abandon it
    # because it cleans the namespace _later_ (when the file scope
    # ends).
    ok( ! WantsMouse->can('has'),  'WantsMouse::has() has been cleaned' );
    ok( ! WantsMouse->can('with'), 'WantsMouse::with() has been cleaned' );
    can_ok( 'WantsMouse', 'foo' );

    # This makes sure that Mouse->init_meta() happens properly
    isa_ok( WantsMouse->meta(), 'Mouse::Meta::Class' );
    isa_ok( WantsMouse->new(), 'Mouse::Object' );

}

{
    package MouseX::Sugar;

    use Mouse ();

    sub wrapped1 {
        my $meta = shift;
        return $meta->name . ' called wrapped1';
    }

    Mouse::Exporter->setup_import_methods(
        with_meta => ['wrapped1'],
        also      => 'Mouse',
    );
}

{
    package WantsSugar;

    MouseX::Sugar->import();

    sub foo { 1 }

    ::can_ok( 'WantsSugar', 'has' );
    ::can_ok( 'WantsSugar', 'with' );
    ::can_ok( 'WantsSugar', 'wrapped1' );
    ::can_ok( 'WantsSugar', 'foo' );
    ::is( wrapped1(), 'WantsSugar called wrapped1',
          'wrapped1 identifies the caller correctly' );

    MouseX::Sugar->unimport();
}

{
    ok( ! WantsSugar->can('has'),  'WantsSugar::has() has been cleaned' );
    ok( ! WantsSugar->can('with'), 'WantsSugar::with() has been cleaned' );
    ok( ! WantsSugar->can('wrapped1'), 'WantsSugar::wrapped1() has been cleaned' );
    can_ok( 'WantsSugar', 'foo' );
}

{
    package MouseX::MoreSugar;

    use Mouse ();

    sub wrapped2 {
        my $caller = shift;
        return $caller . ' called wrapped2';
    }

    sub as_is1 {
        return 'as_is1';
    }

    Mouse::Exporter->setup_import_methods(
        with_caller => ['wrapped2'],
        as_is       => ['as_is1'],
        also        => 'MouseX::Sugar',
    );
}

{
    package WantsMoreSugar;

    MouseX::MoreSugar->import();

    sub foo { 1 }

    ::can_ok( 'WantsMoreSugar', 'has' );
    ::can_ok( 'WantsMoreSugar', 'with' );
    ::can_ok( 'WantsMoreSugar', 'wrapped1' );
    ::can_ok( 'WantsMoreSugar', 'wrapped2' );
    ::can_ok( 'WantsMoreSugar', 'as_is1' );
    ::can_ok( 'WantsMoreSugar', 'foo' );
    ::is( wrapped1(), 'WantsMoreSugar called wrapped1',
          'wrapped1 identifies the caller correctly' );
    ::is( wrapped2(), 'WantsMoreSugar called wrapped2',
          'wrapped2 identifies the caller correctly' );
    ::is( as_is1(), 'as_is1',
          'as_is1 works as expected' );

    MouseX::MoreSugar->unimport();
}

{
    ok( ! WantsMoreSugar->can('has'),  'WantsMoreSugar::has() has been cleaned' );
    ok( ! WantsMoreSugar->can('with'), 'WantsMoreSugar::with() has been cleaned' );
    ok( ! WantsMoreSugar->can('wrapped1'), 'WantsMoreSugar::wrapped1() has been cleaned' );
    ok( ! WantsMoreSugar->can('wrapped2'), 'WantsMoreSugar::wrapped2() has been cleaned' );
    ok( ! WantsMoreSugar->can('as_is1'), 'WantsMoreSugar::as_is1() has been cleaned' );
    can_ok( 'WantsMoreSugar', 'foo' );
}

{
    package My::Metaclass;
    use Mouse;
    BEGIN { extends 'Mouse::Meta::Class' }

    package My::Object;
    use Mouse;
    BEGIN { extends 'Mouse::Object' }

    package HasInitMeta;

    use Mouse ();

    sub init_meta {
        shift;
        return Mouse->init_meta( @_,
                                 metaclass  => 'My::Metaclass',
                                 base_class => 'My::Object',
                               );
    }

    Mouse::Exporter->setup_import_methods( also => 'Mouse' );
}

{
    package NewMeta;

    HasInitMeta->import();
}

{
    isa_ok( NewMeta->meta(), 'My::Metaclass' );
    isa_ok( NewMeta->new(), 'My::Object' );
}

{
    package MouseX::CircularAlso;

    use Mouse ();

    ::dies_ok(
        sub {
            Mouse::Exporter->setup_import_methods(
                also => [ 'Mouse', 'MouseX::CircularAlso' ],
            );
        },
        'a circular reference in also dies with an error'
    );

    ::like(
        $@,
        qr/\QCircular reference in 'also' parameter to Mouse::Exporter between MouseX::CircularAlso and MouseX::CircularAlso/,
        'got the expected error from circular reference in also'
    );
}

{
    package MouseX::NoAlso;

    use Mouse ();

    ::dies_ok(
        sub {
            Mouse::Exporter->setup_import_methods(
                also => [ 'NoSuchThing' ],
            );
        },
        'a package which does not use Mouse::Exporter in also dies with an error'
    );

    ::like(
        $@,
        qr/\QPackage in also (NoSuchThing) does not seem to use Mouse::Exporter (is it loaded?) at /,
        'got the expected error from a reference in also to a package which is not loaded'
    );
}

{
    package MouseX::NotExporter;

    use Mouse ();

    ::dies_ok(
        sub {
            Mouse::Exporter->setup_import_methods(
                also => [ 'Mouse::Meta::Method' ],
            );
        },
        'a package which does not use Mouse::Exporter in also dies with an error'
    );

    ::like(
        $@,
        qr/\QPackage in also (Mouse::Meta::Method) does not seem to use Mouse::Exporter at /,
        'got the expected error from a reference in also to a package which does not use Mouse::Exporter'
    );
}

{
    package MouseX::OverridingSugar;

    use Mouse ();

    sub has {
        my $caller = shift;
        return $caller . ' called has';
    }

    Mouse::Exporter->setup_import_methods(
        with_caller => ['has'],
        also        => 'Mouse',
    );
}

{
    package WantsOverridingSugar;

    MouseX::OverridingSugar->import();

    ::can_ok( 'WantsOverridingSugar', 'has' );
    ::can_ok( 'WantsOverridingSugar', 'with' );
    ::is( has('foo'), 'WantsOverridingSugar called has',
          'has from MouseX::OverridingSugar is called, not has from Mouse' );

    MouseX::OverridingSugar->unimport();
}

{
    ok( ! WantsSugar->can('has'),  'WantsSugar::has() has been cleaned' );
    ok( ! WantsSugar->can('with'), 'WantsSugar::with() has been cleaned' );
}

{
    package NonExistentExport;

    use Mouse ();

    ::stderr_like {
        Mouse::Exporter->setup_import_methods(
            also => ['Mouse'],
            with_caller => ['does_not_exist'],
        );
    } qr/^Trying to export undefined sub NonExistentExport::does_not_exist/,
      "warns when a non-existent method is requested to be exported";
}

{
    package WantsNonExistentExport;

    NonExistentExport->import;

    ::ok(!__PACKAGE__->can('does_not_exist'),
         "undefined subs do not get exported");
}

{
    package AllOptions;
    use Mouse ();
    use Mouse::Exporter;

    Mouse::Exporter->setup_import_methods(
        also        => ['Mouse'],
        with_meta   => [ 'with_meta1', 'with_meta2' ],
        with_caller => [ 'with_caller1', 'with_caller2' ],
        as_is       => ['as_is1'],
    );

    sub with_caller1 {
        return @_;
    }

    sub with_caller2 (&) {
        return @_;
    }

    sub as_is1 {2}

    sub with_meta1 {
        return @_;
    }

    sub with_meta2 (&) {
        return @_;
    }
}

{
    package UseAllOptions;

    AllOptions->import();
}

{
    can_ok( 'UseAllOptions', $_ )
        for qw( with_meta1 with_meta2 with_caller1 with_caller2 as_is1 );

    {
        my ( $caller, $arg1 ) = UseAllOptions::with_caller1(42);
        is( $caller, 'UseAllOptions', 'with_caller wrapped sub gets the right caller' );
        is( $arg1, 42, 'with_caller wrapped sub returns argument it was passed' );
    }

    {
        my ( $meta, $arg1 ) = UseAllOptions::with_meta1(42);
        isa_ok( $meta, 'Mouse::Meta::Class', 'with_meta first argument' );
        is( $arg1, 42, 'with_meta1 returns argument it was passed' );
    }

    is(
        prototype( UseAllOptions->can('with_caller2') ),
        prototype( AllOptions->can('with_caller2') ),
        'using correct prototype on with_meta function'
    );

    is(
        prototype( UseAllOptions->can('with_meta2') ),
        prototype( AllOptions->can('with_meta2') ),
        'using correct prototype on with_meta function'
    );
}

{
    package UseAllOptions;
    AllOptions->unimport();
}

{
    ok( ! UseAllOptions->can($_), "UseAllOptions::$_ has been unimported" )
        for qw( with_meta1 with_meta2 with_caller1 with_caller2 as_is1 );
}
