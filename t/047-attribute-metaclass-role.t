#!/usr/bin/env perl
use strict;
use warnings;
use Test::More tests => 7;
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

    package # hide me from search.cpan.org
        Mouse::Meta::Attribute::Custom::Number;
    sub register_implementation { 'MouseX::AttributeHelpers::Number' }

    1;
    
    package Foo;
    use Mouse::Role;

    has 'i' => (
        metaclass => 'Number',
        is => 'rw',
        isa => 'Int',
        provides => {
            'add' => 'add_number'
        },
    );
    sub f_m {}

    package Bar;
    use Mouse::Role;

    has 'j' => (
        metaclass => 'Number',
        is => 'rw',
        isa => 'Int',
        provides => {
            'add' => 'add_number_j'
        },
    );
    sub b_m {}

    package Klass1;
    use Mouse;
    with 'Foo';

    package Klass2;
    use Mouse;
    with 'Foo', 'Bar';

};

{
    # normal
    can_ok 'Klass1', 'add_number';
    my $k = Klass1->new(i=>3);
    $k->add_number(4);
    is $k->i, 7;
}

{
    # combine
    can_ok 'Klass2', 'f_m';
    can_ok 'Klass2', 'b_m';
    can_ok 'Klass2', 'add_number';
    can_ok 'Klass2', 'add_number_j';
    my $k = Klass2->new(i=>3);
    $k->add_number(4);
    is $k->i, 7;
}


