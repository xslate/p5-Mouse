#!/usr/bin/env perl
# originally mouse_bad.pl, reported by chocolateboy (RT #54203)

use constant HAS_PATH_CLASS => eval{ require Path::Class };
use Test::More HAS_PATH_CLASS ? (tests => 4) : (skip_all => 'Testing with Path::Class');

package MyClass;

use Mouse;
use Path::Class qw(file);

has path => (
    is  => 'rw',
    isa => 'Str',
);

sub BUILD {
    my $self = shift;
    my $path1 = file($0)->stringify;
    ::ok(defined $path1, 'file($0)->stringify');

    $self->path(file($0)->stringify);
    my $path2 = $self->path();
    ::ok(defined $path2, '$self->path(file($0)->stringify)');

    my $path3 = $self->path(file($0)->stringify);
    ::ok(defined $path3, 'my $path3 = $self->path(file($0)->stringify)');
}

package main;

my $object = MyClass->new();
ok defined($object->path);
