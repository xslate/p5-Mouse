#!/usr/bin/env perl
use strict;
use warnings;
use Test::More tests => 7;
use Test::Exception;

use Mouse::Util::TypeConstraints;

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

my $st = subtype as 'Str', where{ length };

ok $st->is_a_type_of('Str');
ok!$st->is_a_type_of('NoemptyStr');

ok $st->check('Foo');
ok!$st->check(undef);
ok!$st->check('');

