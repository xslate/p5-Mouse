#!/usr/bin/perl -w
use Test::More tests => 4;
use Test::Exception;

use Mouse::Util::TypeConstraints;

{
    package Class;
    sub new {
        my $class = shift;
        return bless { @_ }, $class;
    }
}

subtype 'Class',
    as 'Object',
    where { $_->isa('Class') };

subtype 'C', as 'Class'; # subtyping without "where"

coerce 'C',
    from 'Str',
    via { Class->new(content => $_) },
    from 'HashRef',
    via { Class->new(content => $_->{content}) };

{
    package A;
    use Mouse;

    has foo => (
        is => 'ro',
        isa => 'C',
        coerce => 1,
        required => 1,
    );
}

lives_and{
    my $a = A->new(foo => 'foobar');
    isa_ok $a->foo, 'Class';
    is $a->foo->{content}, 'foobar';
};

lives_and{
    my $a = A->new(foo => { content => 42 });
    isa_ok $a->foo, 'Class';
    is $a->foo->{content}, 42;
};
