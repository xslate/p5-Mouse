#!perl
use strict;
use warnings;

use if 'Mouse' eq 'Moose',
    'Test::More' => skip_all => 'Moose does nots support strict constructor';
use Test::More;
use Test::Mouse;
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

    has baz => (
        is      => 'rw',
        default => 42,
    );

    __PACKAGE__->meta->strict_constructor(1);
}
{
    package MySubClass;
    use Mouse;
    extends 'MyClass';
}

with_immutable sub {
    lives_and {
        my $o = MyClass->new(foo => 1);
        isa_ok($o, 'MyClass');
        is $o->baz, 42;
    } 'correc use of the constructor';

    lives_and {
        my $o = MyClass->new(foo => 1, baz => 10);
        isa_ok($o, 'MyClass');
        is $o->baz, 10;
    } 'correc use of the constructor';


    throws_ok {
        MyClass->new(foo => 1, hoge => 42);
    } qr/\b hoge \b/xms;

    throws_ok {
        MyClass->new(foo => 1, bar => 42);
    } qr/\b bar \b/xms, "init_arg => undef";


    eval {
        MyClass->new(aaa => 1, bbb => 2, ccc => 3);
    };
    like $@, qr/\b aaa \b/xms;
    like $@, qr/\b bbb \b/xms;
    like $@, qr/\b ccc \b/xms;

    eval {
        MySubClass->new(aaa => 1, bbb => 2, ccc => 3);
    };
    like $@, qr/\b aaa \b/xms;
    like $@, qr/\b bbb \b/xms;
    like $@, qr/\b ccc \b/xms;
}, qw(MyClass MySubClass);

done_testing;
