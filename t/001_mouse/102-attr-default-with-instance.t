use strict;
use warnings;
use Test::More;

{
    package Foo;
    use Mouse;

    has bar => (
        is => "rw",
        default => sub {
            my($self) = @_;
            return $self->baz;
        },
    );

    sub baz { "baz" }
}

my $bar = Foo->meta->find_attribute_by_name('bar') or die "cannot find attr";
is ref($bar->default), "CODE", "default() returns CodeRef";
is $bar->default(Foo->new), "baz", 'default($instance) returns resolved values';

done_testing;
