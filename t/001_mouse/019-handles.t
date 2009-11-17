#!/usr/bin/env perl
use strict;
use warnings;
use Test::More tests => 27;
use Test::Exception;

do {
    package Person;

    sub new {
        my $class = shift;
        my %args  = @_;

        bless \%args, $class;
    }

    sub name { $_[0]->{name} = $_[1] if @_ > 1; $_[0]->{name} }
    sub age { $_[0]->{age} = $_[1] if @_ > 1; $_[0]->{age} }

    package Class;
    use Mouse;

    has person => (
        is        => 'rw',
        lazy      => 1,
        default   => sub { Person->new(age => 37, name => "Chuck") },
        predicate => 'has_person',
        handles   => {
            person_name => 'name',
            person_age  => 'age',
        },
    );

    has me => (
        is => 'rw',
        default => sub { Person->new(age => 21, name => "Shawn") },
        predicate => 'quid',
        handles => [qw/name age/],
    );

    TODO: {
        local our $TODO = "Mouse lacks this";
        eval {
            has error => (
                handles => "string",
            );
        };
        ::ok(!$@, "handles => role");
    }

    TODO: {
        local our $TODO = "Mouse lacks this";
        eval {
            has error2 => (
                handles => \"ref_to_string",
            );
        };
        ::ok(!$@, "handles => \\str");
    }

    TODO: {
        local our $TODO = "Mouse lacks this";
        eval {
            has error4 => (
                handles => sub { "code" },
            );
        };
        ::ok(!$@, "handles => sub { code }");
    }
};

can_ok(Class => qw(person has_person person_name person_age name age quid));

my $object = Class->new;
ok(!$object->has_person, "don't have a person yet");
$object->person_name("Todd");
ok($object->has_person, "calling person_name instantiated person");
ok($object->person, "we really do have a person");

is($object->person_name, "Todd", "handles method");
is($object->person->name, "Todd", "traditional lookup");
is($object->person_age, 37, "handles method");
is($object->person->age, 37, "traditional lookup");

my $object2 = Class->new(person => Person->new(name => "Philbert"));
ok($object2->has_person, "we have a person from the constructor");
is($object2->person_name, "Philbert", "handles method");
is($object2->person->name, "Philbert", "traditional lookup");
is($object2->person_age, undef, "no age because we didn't use the default");
is($object2->person->age, undef, "no age because we didn't use the default");


ok($object->quid, "we have a Shawn");
is($object->name, "Shawn", "name handle");
is($object->age, 21, "age handle");
is($object->me->name, "Shawn", "me->name");
is($object->me->age, 21, "me->age");

is_deeply(
    $object->meta->get_attribute('me')->handles,
    [ 'name', 'age' ],
    "correct handles layout for 'me'",
);

is_deeply(
    $object->meta->get_attribute('person')->handles,
    { person_name => 'name', person_age => 'age' },
    "correct handles layout for 'person'",
);


{
    local $TODO = "failed on some environment, but I don't know why it happens (gfx)";
    throws_ok{
        $object->person(undef);
        $object->person_name();
    } qr/Cannot delegate person_name to name because the value of person is not defined/;

    throws_ok{
        $object->person([]);
        $object->person_age();
    } qr/Cannot delegate person_age to age because the value of person is not an object/;
}

eval{
    $object->person(undef);
    $object->person_name();
};
like $@, qr/Cannot delegate person_name to name because the value of person is not defined/;

eval{
    $object->person([]);
    $object->person_age();
};
like $@, qr/Cannot delegate person_age to age because the value of person is not an object/;


