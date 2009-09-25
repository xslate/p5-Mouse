#!/usr/bin/env perl
use strict;
use warnings;

use Test::More tests => 31;
use Test::Exception;

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
};

sub do_test{
    my $self = Class->new(type => 'accessor');
    $self->self($self);

    my $self2 = Class->new(type => 'middle');
    my $self3 = Class->new(type => 'constructor', self => $self2);
    $self2->self($self3);

    for my $object ($self, $self2, $self3) {
        ok(Scalar::Util::isweak($object->{self}), "weak reference");
        ok($object->self->self->self->self, "we've got circularity");
    }
}

do_test();

is($destroyed{accessor}, 1, "destroyed from the accessor");
is($destroyed{constructor}, 1, "destroyed from the constructor");
is($destroyed{middle}, 1, "casuality of war");

Class->meta->make_immutable();
ok(Class->meta->is_immutable, 'make_immutable made it immutable');
do_test();

is($destroyed{accessor}, 2, "destroyed from the accessor (after make_immutable)");
is($destroyed{constructor}, 2, "destroyed from the constructor (after make_immutable)");
is($destroyed{middle}, 2, "casuality of war (after make_immutable)");


ok(!Class->meta->get_attribute('type')->is_weak_ref, "type is not a weakref");
ok(Class->meta->get_attribute('self')->is_weak_ref, "self IS a weakref");

do {
    package Class2;
    use Mouse;

    has value => (
        is => 'rw',
        default => 10,
        weak_ref => 1,
    );
};

ok(Class2->meta->get_attribute('value')->is_weak_ref, "value IS a weakref");

lives_ok {
    my $obj = Class2->new;
    is($obj->value, 10, "weak_ref doesn't apply to non-refs");
};

my $obj2 = Class2->new;
lives_ok {
    $obj2->value({});
};

is_deeply($obj2->value, undef, "weakened the reference even with a nonref default");

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

ok(Class3->meta->get_attribute('hashref')->is_weak_ref, "hashref IS a weakref");
