use strict;
use warnings;
use Test::More tests => 2;
use Test::Exception;

my $i;

{
    package Parent;
    use Mouse;
    sub DEMOLISH {
        main::is $i++, 1;
    }
    no Mouse;
    __PACKAGE__->meta->make_immutable;
}

{
    package Child;
    use Mouse;
    extends 'Parent';
    sub DEMOLISH {
        main::is $i++, 0;
    }
    __PACKAGE__->meta->make_immutable;
}

Child->new();

