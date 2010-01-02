#!perl -w
# reported by Christine Spang (RT #53286)
package Foo;
use Mouse;

has app_handle => (
    is       => 'rw',
    isa      => 'Baz',
    required => 1,
);

has handle => (
    is       => 'rw',
    isa      => 'Int',
    # app_handle should not be undef here!
    default  => sub { shift->app_handle->handle() },
);

no Mouse;

1;

package Bar;
use Mouse;

has app_handle => (
    is       => 'rw',
    isa      => 'Baz',
    required => 1,
);

sub do_something {
    my $self = shift;
    my $foo = Foo->new( app_handle => $self->app_handle );
    return $foo->handle;
}

no Mouse;

1;

package Baz;
use Mouse;

sub handle {
    # print "This works correctly.\n";
    return 1;
}

no Mouse;

1;

package main;
use strict;
use warnings;
use Test::More tests => 2;
use Test::Exception;

my $bar = Bar->new( app_handle => Baz->new() );
ok($bar, "Test class Bar instantiated w/attribute app_handle Baz");

# Trigger the default sub of baz's handle attribute, which tries to call
# a method on an attribute which was set to an object passed in via the
# constructor.
lives_and { is($bar->do_something(), 1, "attribute was passed in okay") };
