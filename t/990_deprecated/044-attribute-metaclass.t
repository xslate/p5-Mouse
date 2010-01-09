#!/usr/bin/env perl
use strict;
use warnings;
use Test::More tests => 2;
use lib 't/lib';

do {
    local $SIG{__WARN__} = sub{ $_[0] =~ /deprecated/ or warn @_ };

    package MouseX::AttributeHelpers::Number;
    use Mouse;
    extends 'Mouse::Meta::Attribute';

    sub create {
        my ($self, @args) = @_;
        my $attr = $self->SUPER::create(@args);
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

    around 'canonicalize_args' => sub {
        my ($next, $self, $name, %args) = @_;

        %args = $next->($self, $name, %args);
        $args{is}  = 'rw'  unless exists $args{is};

        return %args;
    };

    package # hide me from search.cpan.org
        Mouse::Meta::Attribute::Custom::Number;
    sub register_implementation { 'MouseX::AttributeHelpers::Number' }

    1;

    package Klass;
    use Mouse;

    has 'number' => (
        metaclass => 'Number',
        isa => 'Int',
        provides => {
            'add' => 'add_number'
        },
    );
};

can_ok 'Klass', 'add_number', 'number';
my $k = Klass->new(number => 3);
$k->add_number(4);
is $k->number, 7;

