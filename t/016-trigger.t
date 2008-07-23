#!/usr/bin/env perl
use strict;
use warnings;
use Test::More tests => 21;
use Test::Exception;

my @trigger;

do {
    package Class;
    use Mouse;

    has attr => (
        is => 'rw',
        default => 10,
        trigger => sub {
            my ($self, $value, $attr) = @_;
            push @trigger, [$self, $value, $attr];
        },
    );

    ::lives_ok {
        has not_error => (
            is => 'ro',
            trigger => sub { },
        );
    } "it's no longer an error to have trigger on a readonly attribute";

    ::throws_ok {
        has error => (
            is => 'ro',
            trigger => [],
        );
    } qr/Trigger must be a CODE ref on attribute \(error\)/;
};

can_ok(Class => 'attr');

my $object = Class->new;
is(@trigger, 0, "trigger not called yet");

is($object->attr, 10, "default value");
is(@trigger, 0, "trigger not called on read");

is($object->attr(50), 50, "setting the value");
is(@trigger, 1, "trigger was called on read");
is_deeply([splice @trigger], [[$object, 50, $object->meta->get_attribute('attr')]], "correct arguments to trigger in the accessor");

my $object2 = Class->new(attr => 100);
is(@trigger, 1, "trigger was called on new with the attribute specified");
is_deeply([splice @trigger], [[$object2, 100, $object2->meta->get_attribute('attr')]], "correct arguments to trigger in the constructor");

do {
    package Parent;
    use Mouse;

    has attr => (
        is      => 'rw',
        trigger => {
            before => sub {
                push @trigger, ['before', @_];
            },
            after => sub {
                push @trigger, ['after', @_];
            },
            around => sub {
                my $code = shift;
                my ($self, $value, $attr) = @_;

                push @trigger, ['around-before', $self, $value, $attr];
                $code->($self, 4 * $value, $attr);
                push @trigger, ['around-after', $self, $value, $attr];
            },
        },
    );

    package Child;
    use Mouse;
    extends 'Parent';

    has '+attr' => (
        default => 10,
    );
};

my $child = Child->new;
is(@trigger, 0, "trigger not called on constructor with default");

is($child->attr, 10, "reader");
is(@trigger, 0, "trigger not called on reader");

is($child->attr(5), 20, "writer");
is_deeply([splice @trigger], [
    ['before',        $child,  5, Child->meta->get_attribute('attr')],
    ['around-before', $child,  5, Child->meta->get_attribute('attr')],
    ['around-after',  $child,  5, Child->meta->get_attribute('attr')],
    ['after',         $child, 20, Child->meta->get_attribute('attr')],
]);

my $parent = Parent->new(attr => 2);
is_deeply([splice @trigger], [
    ['before',        $parent, 2, Parent->meta->get_attribute('attr')],
    ['around-before', $parent, 2, Parent->meta->get_attribute('attr')],
    ['around-after',  $parent, 2, Parent->meta->get_attribute('attr')],
    ['after',         $parent, 8, Parent->meta->get_attribute('attr')],
]);

is($parent->attr, 8, "reader");
is(@trigger, 0, "trigger not called on reader");

is($parent->attr(10), 40, "writer");
is_deeply([splice @trigger], [
    ['before',        $parent, 10, Parent->meta->get_attribute('attr')],
    ['around-before', $parent, 10, Parent->meta->get_attribute('attr')],
    ['around-after',  $parent, 10, Parent->meta->get_attribute('attr')],
    ['after',         $parent, 40, Parent->meta->get_attribute('attr')],
]);

