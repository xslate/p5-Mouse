#!/usr/bin/env perl
use strict;
use warnings;
use Test::More tests => 16;
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
    } qr/Trigger must be a CODE or HASH ref on attribute \(error\)/;
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
    package Class2;
    use Mouse;

    has attr => (
        is      => 'rw',
        default => 10,
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
};

my $o2 = Class2->new;
is(@trigger, 0, "trigger not called on constructor with default");

is($o2->attr, 10, "reader");
is(@trigger, 0, "trigger not called on reader");

is($o2->attr(5), 20, "writer");
is_deeply([splice @trigger], [
    ['before',        $o2,  5, $o2->meta->get_attribute('attr')],
    ['around-before', $o2,  5, $o2->meta->get_attribute('attr')],
    ['around-after',  $o2,  5, $o2->meta->get_attribute('attr')],
    ['after',         $o2, 20, $o2->meta->get_attribute('attr')],
]);

