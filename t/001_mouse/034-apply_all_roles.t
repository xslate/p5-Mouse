#!perl
use strict;
use warnings;
use Test::More;

my $foo = 0;
my $bar = 0;
{
    package FooRole;
    use Mouse::Role;
    sub foo { 'ok1' }

    before method => sub { $foo++ };
}

{
    package BarRole;
    use Mouse::Role;
    sub bar { 'ok2' }

    before method => sub { $bar++ };
}

{
    package Baz;
    use Mouse;
    sub method {}
    no Mouse;
}

{
    package Qux;
    use Mouse;
    sub method {}
    no Mouse;
}

Mouse::Util::apply_all_roles('Baz', 'BarRole', 'FooRole');

my $baz = Baz->new;
is $baz->foo, 'ok1';
is $baz->bar, 'ok2';
is join(",", sort $baz->meta->get_method_list), 'bar,foo,meta,method';

# applyu to instance

my $qux = Qux->new;
Mouse::Util::apply_all_roles($qux, 'FooRole');
note $qux;
$foo = 0;
$bar = 0;
$qux->method;
is $foo, 1;
is $bar, 0;

$qux = Qux->new;
Mouse::Util::apply_all_roles($qux, 'BarRole');
note $qux;
$foo = 0;
$bar = 0;
$qux->method;
is $foo, 0;
is $bar, 1;

$qux = Qux->new;
Mouse::Util::apply_all_roles($qux, 'FooRole', 'BarRole');
note $qux;
$foo = 0;
$bar = 0;
$qux->method;
is $foo, 1;
is $bar, 1;

done_testing;

