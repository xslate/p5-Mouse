#!/usr/bin/env perl
use strict;
use warnings;
use Test::More;
use Test::Exception;

my @trigger;

do {
    package Class;
    use Mouse;

    has attr => (
        is => 'rw',
        default => 10,
        trigger => sub {
            push @trigger, [@_];
        },
    );

    has foobar => ( # from Net::Google::DataAPI
        is  => 'rw',
        isa => 'Str',

        lazy => 1,
        trigger => sub{ $_[0]->update },
        default => sub{ 'piyo' },

        clearer => 'clear_foobar',
    );

    sub update {
        my($self) = @_;
        $self->clear_foobar;
    }

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
is_deeply([splice @trigger], [[$object, 50, 10]], "correct arguments to trigger in the accessor");

is($object->foobar,        'piyo');
lives_ok { $object->foobar('baz') } "triggers that clear the attr";

is($object->foobar,        'piyo', "call clearer in triggers");

my $object2 = Class->new(attr => 100);
is(@trigger, 1, "trigger was called on new with the attribute specified");
is_deeply([splice @trigger], [[$object2, 100]], "correct arguments to trigger in the constructor");

done_testing;
