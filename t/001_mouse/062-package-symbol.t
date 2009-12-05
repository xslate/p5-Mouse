#!perl
use strict;
use warnings;

use Test::More;

{
    package Foo;
    use Mouse;

    sub code { 42 }

    our $scalar = 'bar';

    our %hash = (a => 'b');

    our @array = ('foo');
}

my $meta = Foo->meta;

foreach my $sym(qw(&code $scalar %hash @array)){
    ok $meta->has_package_symbol($sym),      "has_package_symbol('$sym')";
}

ok !$meta->has_package_symbol('$hogehoge');
ok !$meta->has_package_symbol('%array');

is $meta->get_package_symbol('&code'),   \&Foo::code;
is $meta->get_package_symbol('$scalar'), \$Foo::scalar;
is $meta->get_package_symbol('%hash'),   \%Foo::hash;
is $meta->get_package_symbol('@array'),  \@Foo::array;

is $meta->get_package_symbol('@hogehoge'), undef;
is $meta->get_package_symbol('%array'),    undef;
is $meta->get_package_symbol('&hash'),     undef;

done_testing;
