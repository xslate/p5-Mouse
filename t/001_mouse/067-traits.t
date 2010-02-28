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

    package ClassC;
    use Mouse;

    #extends qw(ClassB ClassA);
    extends qw(ClassA);

    sub c {}
}

does_ok(ClassA->meta,                  'MyMouseX::Foo::Class');
does_ok(ClassA->meta->get_method('a'), 'MyMouseX::Foo::Method');

does_ok(ClassB->meta,                  'MyMouseX::Bar::Class');
does_ok(ClassB->meta->get_method('b'), 'MyMouseX::Bar::Method');

# for ClassC

does_ok(ClassC->meta,                  'MyMouseX::Foo::Class');

{
    local $TODO = 'Metaclass incompatibility is not completed';
    does_ok(ClassC->meta->get_method('c'), 'MyMouseX::Foo::Method');
}
#does_ok(ClassC->meta,                  'MyMouseX::Bar::Class');
#does_ok(ClassC->meta->get_method('c'), 'MyMouseX::Bar::Method');

done_testing;
