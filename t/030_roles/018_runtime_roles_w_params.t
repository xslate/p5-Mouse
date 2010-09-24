#!/usr/bin/perl

use strict;
use warnings;

use Test::More tests => 21;
use Test::Exception;



{
    package Foo;
    use Mouse;
    has 'bar' => (is => 'ro');

    package Bar;
    use Mouse::Role;

    has 'baz' => (is => 'ro', default => 'BAZ');
}

# normal ...
{
    my $foo = Foo->new(bar => 'BAR');
    isa_ok($foo, 'Foo');

    is($foo->bar, 'BAR', '... got the expect value');
    ok(!$foo->can('baz'), '... no baz method though');

    lives_ok {
        Bar->meta->apply($foo)
    } '... this works';

    is($foo->bar, 'BAR', '... got the expect value');
    ok($foo->can('baz'), '... we have baz method now');
    is($foo->baz, 'BAZ', '... got the expect value');
}

# with extra params ...
{
    my $foo = Foo->new(bar => 'BAR');
    isa_ok($foo, 'Foo');

    is($foo->bar, 'BAR', '... got the expect value');
    ok(!$foo->can('baz'), '... no baz method though');

    lives_ok {
        Bar->meta->apply($foo, (rebless_params => { baz => 'FOO-BAZ' }))
    } '... this works';

    is($foo->bar, 'BAR', '... got the expect value');
    ok($foo->can('baz'), '... we have baz method now');
    {
        local $TODO = 'rebless_params is not implemented';
        is($foo->baz, 'FOO-BAZ', '... got the expect value');
    }
}

# with extra params ...
{
    my $foo = Foo->new(bar => 'BAR');
    isa_ok($foo, 'Foo');

    is($foo->bar, 'BAR', '... got the expect value');
    ok(!$foo->can('baz'), '... no baz method though');

    lives_ok {
        Bar->meta->apply($foo, (rebless_params => { bar => 'FOO-BAR', baz => 'FOO-BAZ' }))
    } '... this works';

    {
        local $TODO = 'rebless params is not implemented';
        is($foo->bar, 'FOO-BAR', '... got the expect value');
    }
    ok($foo->can('baz'), '... we have baz method now');
    {
        local $TODO = 'rebless params is not implemented';
        is($foo->baz, 'FOO-BAZ', '... got the expect value');
    }
}


