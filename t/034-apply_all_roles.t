#!/usr/bin/env perl
use strict;
use warnings;
use Test::More tests => 4;
use Test::Exception;

{
    package FooRole;
    use Mouse::Role;
    sub foo { 'ok1' }
}

{
    package BarRole;
    use Mouse::Role;
    sub bar { 'ok2' }
}

{
    package Baz;
    use Mouse;
    no Mouse;
}

throws_ok { Mouse::Util::apply_all_roles('Baz', 'BarRole', 'FooRole') } qr{Mouse::Util only supports 'apply_all_roles' on individual roles at a time};

Mouse::Util::apply_all_roles('Baz', 'BarRole');
Mouse::Util::apply_all_roles('Baz', 'FooRole');

my $baz = Baz->new;
is $baz->foo, 'ok1';
is $baz->bar, 'ok2';
is join(",", sort $baz->meta->get_method_list), 'bar,foo';

