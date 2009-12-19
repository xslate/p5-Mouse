#!/usr/bin/env perl
use strict;
use warnings;
use Test::More tests => 14;
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

    subtype 'MyClass'
        => as 'Object'
        => where { $_->isa(__PACKAGE__) };

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

lives_and{
    my $tc = find_type_constraint('MyClass');
    ok $tc->check(My::Class->new());
    ok!$tc->check('My::Class');
    ok!$tc->check([]);
    ok!$tc->check(undef);
};

package Foo;
use Mouse::Util::TypeConstraints;

$st = subtype as 'Int', where{ $_ > 0 };

::ok $st->is_a_type_of('Int');
::ok $st->check(10);
::ok!$st->check(0);

