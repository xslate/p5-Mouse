#!/usr/bin/perl

use strict;
use warnings;

use Test::More;

{
    package Foo;
    use Mouse;

    sub DEMOLISH {
        my $self = shift;
        my ($igd) = @_;
        ::ok(
            !$igd,
            'in_global_destruction state is passed to DEMOLISH properly (false)'
        );
    }
}

{
    my $foo = Foo->new;
}

{
    package Bar;
    use Mouse;

    sub DEMOLISH {
        my $self = shift;
        my ($igd) = @_;
        ::ok(
            !$igd,
            'in_global_destruction state is passed to DEMOLISH properly (false)'
        );
    }

    __PACKAGE__->meta->make_immutable;
}

{
    my $bar = Bar->new;
}

$? = 0;

my $blib = $INC{'blib.pm'} ? ' -Mblib ' : '';
my @status = `$^X $blib t/010_basics/020-global-destruction-helper.pl`;

ok $status[0], 'in_global_destruction state is passed to DEMOLISH properly (true)';
ok $status[1], 'in_global_destruction state is passed to DEMOLISH properly (true)';

is $?, 0, 'exited successfully';

done_testing;
