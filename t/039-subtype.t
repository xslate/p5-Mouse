#!/usr/bin/env perl
use strict;
use warnings;
use Test::More tests => 2;
use Test::Exception;

do {
    package My::Class;
    use Mouse;
    use Mouse::Util::TypeConstraints;

    subtype 'NonemptyStr'
        => as 'Str'
        => where { length $_ }
        => message { "The string is empty!" };

    has name => (
        is  => 'ro',
        isa => 'NonemptyStr',
    );
};

ok(My::Class->new(name => 'foo'));

throws_ok { My::Class->new(name => '') } qr/^Attribute \(name\) does not pass the type constraint because: The string is empty!/;

