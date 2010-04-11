#!/usr/bin/env perl
use strict;
use warnings;
use Test::More;
use Test::Exception;

my %triggered;
{
    package Foo;
    use Mouse;

    has foo => (
        isa => "Str",
        is  => "rw",
        default => "foo",
    );

    has bar => (
        isa => "ArrayRef",
        is  => "rw",
    );

    has baz => (
        is => 'rw',
        init_arg => undef,
    );

    has quux => (
        is => 'rw',
        init_arg => 'quuux',
        trigger => sub{
            my($self, $value) = @_;
            $triggered{$self} = $value;
        },
    );

    sub clone {
        my ($self, @args) = @_;
        $self->meta->clone_object($self, @args);
    }
}

{
    package Bar;
    use Mouse;

    has id => (
        is  => 'ro',
        isa => 'Str',

        required => 1,
    );

    sub clone {
        my ($self, @args) = @_;
        $self->meta->clone_object($self, @args);
    }
}

my $foo = Foo->new(bar => [ 1, 2, 3 ], quuux => "indeed");

is($foo->foo, "foo", "attr 1",);
is($foo->quux, "indeed", "init_arg respected");

is $triggered{$foo}, "indeed";

is_deeply($foo->bar, [ 1 .. 3 ], "attr 2");
$foo->baz("foo");

my $clone = $foo->clone(foo => "dancing", baz => "bar", quux => "nope", quuux => "yes");

is $triggered{$foo},   "indeed";
is $triggered{$clone}, "yes", 'clone_object() invokes triggers';

is($clone->foo, "dancing", "overridden attr");
is_deeply($clone->bar, [ 1 .. 3 ], "clone attr");
is($clone->baz, "foo", "init_arg=undef means the attr is ignored");
is($clone->quux, "yes", "clone uses init_arg and not attribute name");

lives_and {
    my $bar = Bar->new(id => 'xyz');
    my $c   = $bar->clone;

    is_deeply $bar, $c, "clone() with required attributes";
};

throws_ok {
    Foo->meta->clone_object("constant");
} qr/You must pass an instance of the metaclass \(Foo\), not \(constant\)/;

throws_ok {
    Foo->meta->clone_object(Foo->meta)
} qr/You must pass an instance of the metaclass \(Foo\), not \(Mouse::Meta::Class=HASH\(\w+\)\)/;

done_testing;
