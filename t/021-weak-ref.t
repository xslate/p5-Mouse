#!/usr/bin/env perl
use strict;
use warnings;
use Test::More tests => 18;
use Test::Exception;
use Scalar::Util 'isweak';

my %destroyed;

do {
    do {
        package Class;
        use Mouse;

        has self => (
            is       => 'rw',
            weak_ref => 1,
        );

        has type => (
            is => 'rw',
        );

        sub DEMOLISH {
            my $self = shift;
            $destroyed{ $self->type }++;
        }
    };

    my $self = Class->new(type => 'accessor');
    $self->self($self);

    my $self2 = Class->new(type => 'middle');
    my $self3 = Class->new(type => 'constructor', self => $self2);
    $self2->self($self3);

    for my $object ($self, $self2, $self3) {
        ok(isweak($object->{self}), "weak reference");
        ok($object->self->self->self->self, "we've got circularity");
    }
};

is($destroyed{accessor}, 1, "destroyed from the accessor");
is($destroyed{constructor}, 1, "destroyed from the constructor");
is($destroyed{middle}, 1, "casuality of war");

ok(!Class->meta->get_attribute('type')->weak_ref, "type is not a weakref");
ok(Class->meta->get_attribute('self')->weak_ref, "self IS a weakref");

do {
    package Class2;
    use Mouse;

    has value => (
        is => 'ro',
        default => 10,
        weak_ref => 1,
    );
};

throws_ok { Class2->new } qr/Can't weaken a nonreference/;
ok(Class2->meta->get_attribute('value')->weak_ref, "value IS a weakref");

do {
    package Class3;
    use Mouse;

    has hashref => (
        is        => 'rw',
        default   => sub { {} },
        weak_ref  => 1,
        predicate => 'has_hashref',
    );
};

my $obj = Class3->new;
is($obj->hashref, undef, "hashref collected immediately because refcount=0");
ok($obj->has_hashref, 'attribute is turned into undef, not deleted from instance');

$obj->hashref({1 => 1});
is($obj->hashref, undef, "hashref collected between set and get because refcount=0");
ok($obj->has_hashref, 'attribute is turned into undef, not deleted from instance');

ok(Class3->meta->get_attribute('hashref')->weak_ref, "hashref IS a weakref");
