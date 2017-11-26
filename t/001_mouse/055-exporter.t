#!perl
use strict;
use warnings;
use Test::More tests => 14;

use Mouse ();

BEGIN{
    package MyMouse;
    use Mouse;
    Mouse::Exporter->setup_import_methods(
        as_is => [qw(foo)],
        also  => [qw(Mouse)],
    );

    sub foo{ 100 }

    package MyMouseEx;
    use Mouse;
    Mouse::Exporter->setup_import_methods(
        as_is => [\&bar],
        also  => [qw(MyMouse)],

#        groups => {
#            foobar_only => [qw(foo bar)],
#        },
    );

    sub bar{ 200 }
}

can_ok 'MyMouse',   qw(import unimport);
can_ok 'MyMouseEx', qw(import unimport);

{
    package MyApp;
    use Test::More;
    use MyMouse;

    can_ok __PACKAGE__, 'meta';
    ok defined(&foo), 'foo is imported';
    ok defined(&has), 'has is also imported';

    no MyMouse;

    ok !defined(&foo), 'foo is unimported';
    ok !defined(&has), 'has is also unimported';
}
{
    package MyAppEx;
    use Test::More;
    use MyMouseEx;

    can_ok __PACKAGE__, 'meta';
    ok defined(&foo), 'foo is imported';
    ok defined(&bar), 'foo is also imported';
    ok defined(&has), 'has is also imported';

    no MyMouseEx;

    ok !defined(&foo), 'foo is unimported';
    ok !defined(&bar), 'foo is also unimported';
    ok !defined(&has), 'has is also unimported';
}

# exporting groups are not implemented in Moose::Exporter
#{
#    package MyAppExTags;
#    use Test::More;
#    use MyMouseEx qw(:foobar_only);
#
#    can_ok __PACKAGE__, 'meta';
#    ok defined(&foo);
#    ok defined(&bar);
#    ok!defined(&has), "export tags";
#}

