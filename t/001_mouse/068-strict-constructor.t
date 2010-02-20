#!perl
use strict;
use warnings;

use Test::More;
use Test::Exception;

{
    package MyClass;
    use Mouse;

    has foo => (
        is => 'rw',
    );

    has bar => (
        is => 'rw',
        init_arg => undef,
    );

    __PACKAGE__->meta->make_immutable(strict_constructor => 1);
}

lives_ok {
    MyClass->new(foo => 1);
};

throws_ok {
    MyClass->new(foo => 1, hoge => 42);
} qr/\b hoge \b/xms;

throws_ok {
    MyClass->new(foo => 1, bar => 42);
} qr/\b bar \b/xms, "init_arg => undef";


throws_ok {
    MyClass->new(aaa => 1, bbb => 2, ccc => 3);
} qr/\b aaa \b/xms;

throws_ok {
    MyClass->new(aaa => 1, bbb => 2, ccc => 3);
} qr/\b bbb \b/xms;

throws_ok {
    MyClass->new(aaa => 1, bbb => 2, ccc => 3);
} qr/\b ccc \b/xms;

done_testing;
