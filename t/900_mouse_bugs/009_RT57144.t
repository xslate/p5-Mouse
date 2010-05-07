#!/usr/bin/perl
# https://rt.cpan.org/Public/Bug/Display.html?id=57144
use strict;
use Test::More;

package Hoge;
use Mouse;

has 'fuga' => (
    is => 'rw',
    isa => 'Str',
    lazy_build => 1,
);

has 'hoge' => (
    is => 'rw',
    isa => 'Str',
    lazy_build => 1,
);

sub _build_fuga {
    shift->hoge;
}

sub _build_hoge {
    eval "use Hoge::Hoge"; ## no critic
    "HOGE";
}

sub msg {
    shift->fuga;
}

package main;
use strict;
use warnings;

my $hoge = Hoge->new;
is $hoge->msg, "HOGE";

done_testing;
