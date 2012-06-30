#!perl -w
use strict;
use Test::More;

{
    package Foo;
    use Mouse;

    package Bar;
    use Mouse;

    has 'root' => (is => 'ro', weak_ref => 1);

    package R;
    use Mouse::Role;
}

my $a = Foo->new;
my $b = Bar->new(root => $a);

my $w = "";
{
    local $SIG{__WARN__} = sub {
        $w .= join "", @_;
    };
    R->meta->apply($b);
}

is $w, "", "no warnings about weak refs";

done_testing;
