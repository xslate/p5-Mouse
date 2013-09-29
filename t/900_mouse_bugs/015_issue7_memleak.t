use strict;
use Test::Requires qw(Test::LeakTrace);
use Test::More tests => 1;

{
    package Foo;

    use Mouse;

    has 'bar' => (
        is => 'rw',
        trigger => sub { }
    );
}

no_leaks_ok {
    my $foo = Foo->new(bar => 'TEST');
    $foo->bar('bar');
};

