#!perl
use strict;
use warnings;
use Test::More tests => 10;
use Test::Mouse;

{
    package MyClass;
    use Mouse;

    has 'foo' => (
        is => 'bare',
    );
}

with_immutable {
    my $obj = MyClass->new();
    my $foo = $obj->meta->get_attribute('foo');
    ok $foo, $obj->meta->is_immutable ? 'immutable' : 'mutable';

    ok !$foo->has_value($obj), 'has_value';

    $foo->set_value($obj, 'bar');
    is $foo->get_value($obj), 'bar', 'set_value/get_value';

    ok $foo->has_value($obj), 'has_value';

    $foo->clear_value($obj);

    ok!$foo->has_value($obj), 'clear_value';

} qw(MyClass);
