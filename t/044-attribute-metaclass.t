#!/usr/bin/env perl
use strict;
use warnings;
use Test::More tests => 2;
use lib 't/lib';

do {
    package MouseX::AttributeHelpers::Number;
    use Mouse;
    extends 'Mouse::Meta::Attribute';

    around 'create' => sub {
        my ($next, @args) = @_;
        my $attr = $next->(@args);
        my %provides = %{$attr->{provides}};
        my $method_constructors = {
            add => sub {
                my ($attr, $name) = @_;
                return sub {
                    $_[0]->$name( $_[0]->$name() + $_[1])
                };
            },
        };
        while (my ($name, $aliased) = each %provides) {
            $attr->associated_class->add_method(
                $aliased => $method_constructors->{$name}->($attr, $attr->name)
            );
        }
        return $attr;
    };

    package # hide me from search.cpan.org
        Mouse::Meta::Attribute::Custom::Number;
    sub register_implementation { 'MouseX::AttributeHelpers::Number' }

    1;

    package Klass;
    use Mouse;

    has 'i' => (
        metaclass => 'Number',
        is => 'rw',
        isa => 'Int',
        provides => {
            'add' => 'add_number'
        },
    );
};

can_ok 'Klass', 'add_number';
my $k = Klass->new(i=>3);
$k->add_number(4);
is $k->i, 7;

