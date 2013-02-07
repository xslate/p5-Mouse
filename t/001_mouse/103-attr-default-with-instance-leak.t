use strict;
use warnings;
use Test::More;

BEGIN {
    eval "use Test::LeakTrace 0.10;";
    plan skip_all => "Test::LeakTrace 0.10 is required for this test" if $@;
}

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

no_leaks_ok {
    $bar->default(Foo->new);
};

done_testing;
