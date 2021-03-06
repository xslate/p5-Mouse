use strict;
# This is automatically generated by author/import-moose-test.pl.
# DO NOT EDIT THIS FILE. ANY CHANGES WILL BE LOST!!!
use t::lib::MooseCompat;
use warnings;

use Test::More;
$TODO = q{Mouse is not yet completed};
use Test::Exception;
use Mouse::Util qw( add_method_modifier );

my $COUNT = 0;
{
    package Foo;
    use Mouse;

    sub foo { }
    sub bar { }
}

lives_ok {
    add_method_modifier('Foo', 'before', [ ['foo', 'bar'], sub { $COUNT++ } ]);
} 'method modifier with an arrayref';

dies_ok {
    add_method_modifier('Foo', 'before', [ {'foo' => 'bar'}, sub { $COUNT++ } ]);
} 'method modifier with a hashref';

my $foo = Foo->new;
$foo->foo;
$foo->bar;
is($COUNT, 2, "checking that the modifiers were installed.");


done_testing;
