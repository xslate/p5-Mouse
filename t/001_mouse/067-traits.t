#!perl
use strict;
use warnings;

use Test::More;

use Test::Mouse qw(does_ok);

BEGIN{
    package MyMouseX::Foo::Method;
    use Mouse::Role;

    sub foo {}

    package MyMouseX::Bar::Method;
    use Mouse::Role;

    sub bar {}

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
}

does_ok(ClassA->meta->get_method('a'), 'MyMouseX::Foo::Method');
does_ok(ClassB->meta->get_method('b'), 'MyMouseX::Bar::Method');

done_testing;
