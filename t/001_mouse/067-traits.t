#!perl
use strict;
use warnings;

use Test::More;

use Test::Mouse qw(does_ok);

BEGIN{ $SIG{__WARN__} = \&Carp::confess }

BEGIN {
    package MyMouseX::Foo::Method;
    use Mouse::Role;

    sub foo_method {}

    package MyMouseX::Foo::Class;
    use Mouse::Role;

    sub foo_class {}

    package MyMouseX::Bar::Method;
    use Mouse::Role;

    sub bar {}

    package MyMouseX::Bar::Class;
    use Mouse::Role;

    sub bar_class {}
}

BEGIN {
    package MyMouseX::Foo;
    use Mouse::Exporter;
    use Mouse::Util::MetaRole;

    Mouse::Exporter->setup_import_methods(
        also => 'Mouse',
    );
    sub init_meta {
        my(undef, %options) = @_;

        my $meta = Mouse->init_meta(%options);
        Mouse::Util::MetaRole::apply_metaroles(
            for             => $options{for_class},
            class_metaroles => {
                class  => ['MyMouseX::Foo::Class'],
                method => ['MyMouseX::Foo::Method'],
            },
        );
    }

    $INC{'MyMouseX/Foo.pm'} = __FILE__;

    package MyMouseX::Bar;
    use Mouse::Exporter;
    use Mouse::Util::MetaRole;

    Mouse::Exporter->setup_import_methods(
        also => 'Mouse',
    );
    sub init_meta {
        my(undef, %options) = @_;

        my $meta = Mouse->init_meta(%options);
        Mouse::Util::MetaRole::apply_metaroles(
            for             => $options{for_class},
            class_metaroles => {
                class  => ['MyMouseX::Bar::Class'],
                method => ['MyMouseX::Bar::Method'],
            },
        );
    }

    $INC{'MyMouseX/Bar.pm'} = __FILE__;
}
{
    package ClassA;
    use MyMouseX::Foo;

    sub a {}

    package ClassB;
    use MyMouseX::Bar;

    sub b {}

    package ClassXAFoo;
    use MyMouseX::Foo;

    extends qw(ClassA);

    sub xa {}

    package ClassXABar;
    use MyMouseX::Bar;

    extends qw(ClassA);

    sub xa {}
}

does_ok(ClassA->meta,                  'MyMouseX::Foo::Class');
does_ok(ClassA->meta->get_method('a'), 'MyMouseX::Foo::Method');

does_ok(ClassB->meta,                  'MyMouseX::Bar::Class');
does_ok(ClassB->meta->get_method('b'), 'MyMouseX::Bar::Method');


does_ok(ClassXAFoo->meta,                   'MyMouseX::Foo::Class');
does_ok(ClassXAFoo->meta->get_method('xa'), 'MyMouseX::Foo::Method');

does_ok(ClassXABar->meta,                   'MyMouseX::Foo::Class');
does_ok(ClassXABar->meta->get_method('xa'), 'MyMouseX::Foo::Method');

does_ok(ClassXABar->meta,                   'MyMouseX::Bar::Class');
does_ok(ClassXABar->meta->get_method('xa'), 'MyMouseX::Bar::Method');


done_testing;
