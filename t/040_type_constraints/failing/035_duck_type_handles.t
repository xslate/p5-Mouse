#!/usr/bin/perl
use strict;
use warnings;

use Test::More tests => 2;
use Test::Exception;

my @phonograph;
{
    package Duck;
    use Mouse;

    sub walk {
        push @phonograph, 'footsteps',
    }

    sub quack {
        push @phonograph, 'quack';
    }

    package Swan;
    use Mouse;

    sub honk {
        push @phonograph, 'honk';
    }

    package DucktypeTest;
    use Mouse;
    use Mouse::Util::TypeConstraints;

    my $ducktype = duck_type 'DuckType' => qw(walk quack);

    has duck => (
        isa     => $ducktype,
        handles => $ducktype,
    );
}

my $t = DucktypeTest->new(duck => Duck->new);
$t->quack;
is_deeply([splice @phonograph], ['quack']);

$t->walk;
is_deeply([splice @phonograph], ['footsteps']);

