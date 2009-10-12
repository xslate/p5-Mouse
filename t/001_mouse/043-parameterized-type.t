#!/usr/bin/env perl
use strict;
use warnings;
use Test::More tests => 46;
use Test::Exception;

{
    {
        package My::Role;
        use Mouse::Role;

        package My::Class;
        use Mouse;

        with 'My::Role';

        package Foo;
        use Mouse;

        has foo => (
            is  => 'ro',
            isa => 'HashRef[Int]',
        );

        has bar => (
            is  => 'ro',
            isa => 'ArrayRef[Int]',
        );

        has complex => (
            is  => 'rw',
            isa => 'ArrayRef[HashRef[Int]]'
        );

        has my_class => (
            is  => 'rw',
            isa => 'ArrayRef[My::Class]',
        );

        has my_role => (
            is  => 'rw',
            isa => 'ArrayRef[My::Role]',
        );
    };

    ok(Foo->meta->has_attribute('foo'));

    lives_and {
        my $hash = { a => 1, b => 2, c => 3 };
        my $array = [ 1, 2, 3 ];
        my $complex = [ { a => 1, b => 1 }, { c => 2, d => 2} ];
        my $foo = Foo->new(foo => $hash, bar => $array, complex => $complex);

        is_deeply($foo->foo(), $hash, "foo is a proper hash");
        is_deeply($foo->bar(), $array, "bar is a proper array");
        is_deeply($foo->complex(), $complex, "complex is a proper ... structure");

        $foo->my_class([My::Class->new]);
        is ref($foo->my_class), 'ARRAY';
        isa_ok $foo->my_class->[0], 'My::Class';

        $foo->my_role([My::Class->new]);
        is ref($foo->my_role), 'ARRAY';

    } "Parameterized constraints work";

    # check bad args
    throws_ok {
        Foo->new( foo => { a => 'b' });
    } qr/Attribute \(foo\) does not pass the type constraint because: Validation failed for 'HashRef\[Int\]' failed with value/, "Bad args for hash throws an exception";

    throws_ok {
        Foo->new( bar => [ a => 'b' ]);
    } qr/Attribute \(bar\) does not pass the type constraint because: Validation failed for 'ArrayRef\[Int\]' failed with value/, "Bad args for array throws an exception";

    throws_ok {
        Foo->new( complex => [ { a => 1, b => 1 }, { c => "d", e => "f" } ] )
    } qr/Attribute \(complex\) does not pass the type constraint because: Validation failed for 'ArrayRef\[HashRef\[Int\]\]' failed with value/, "Bad args for complex types throws an exception";

    throws_ok {
        Foo->new( my_class => [ 10 ] );
    } qr/Attribute \(my_class\) does not pass the type constraint because: Validation failed for 'ArrayRef\[My::Class\]' failed with value/;
    throws_ok {
        Foo->new( my_class => [ {foo => 'bar'} ] );
    } qr/Attribute \(my_class\) does not pass the type constraint because: Validation failed for 'ArrayRef\[My::Class\]' failed with value/;


    throws_ok {
        Foo->new( my_role => [ 20 ] );
    } qr/Attribute \(my_role\) does not pass the type constraint because: Validation failed for 'ArrayRef\[My::Role\]' failed with value/;
    throws_ok {
        Foo->new( my_role => [ {foo => 'bar'} ] );
    } qr/Attribute \(my_role\) does not pass the type constraint because: Validation failed for 'ArrayRef\[My::Role\]' failed with value/;
}

{
    {
        package Bar;
        use Mouse;
        use Mouse::Util::TypeConstraints;

        subtype 'Bar::List'
            => as 'ArrayRef[HashRef]'
        ;
        coerce 'Bar::List'
            => from 'ArrayRef[Str]'
            => via {
                [ map { +{ $_ => 1 } } @$_ ]
            }
        ;
        has 'list' => (
            is => 'ro',
            isa => 'Bar::List',
            coerce => 1,
        );
    }

    lives_and {
        my @list = ( {a => 1}, {b => 1}, {c => 1} );
        my $bar = Bar->new(list => [ qw(a b c) ]);

        is_deeply( $bar->list, \@list, "list is as expected");
    } "coercion works";

    throws_ok {
        Bar->new(list => [ { 1 => 2 }, 2, 3 ]);
    } qr/Attribute \(list\) does not pass the type constraint because: Validation failed for 'Bar::List' failed with value/, "Bad coercion parameter throws an error";
}

use Mouse::Util::TypeConstraints;

my $t = Mouse::Util::TypeConstraints::find_or_parse_type_constraint('Maybe[Int]');
ok $t->is_a_type_of($t),            "$t is a type of $t";
ok $t->is_a_type_of('Maybe'),       "$t is a type of Maybe";

# XXX: how about 'MaybeInt[ Int ]'?
ok $t->is_a_type_of('Maybe[Int]'),  "$t is a type of Maybe[Int]";

ok!$t->is_a_type_of('Int');

ok $t->check(10);
ok $t->check(undef);
ok!$t->check(3.14);

my $u = subtype 'MaybeInt', as 'Maybe[Int]';
ok $u->is_a_type_of($t),             "$t is a type of $t";
ok $u->is_a_type_of('Maybe'),        "$t is a type of Maybe";

# XXX: how about 'MaybeInt[ Int ]'?
ok $u->is_a_type_of('Maybe[Int]'),   "$t is a type of Maybe[Int]";

ok!$u->is_a_type_of('Int');

ok $u->check(10);
ok $u->check(undef);
ok!$u->check(3.14);

# XXX: undefined hehaviour
# ok $t->is_a_type_of($u);
# ok $u->is_a_type_of($t);

my $w = subtype as 'Maybe[ ArrayRef | HashRef ]';

ok $w->check(undef);
ok $w->check([]);
ok $w->check({});
ok!$w->check(sub{});

ok $w->is_a_type_of('Maybe');
ok $w->is_a_type_of('Maybe[ArrayRef|HashRef]');
ok!$w->is_a_type_of('ArrayRef');

my $x = Mouse::Util::TypeConstraints::find_or_parse_type_constraint('ArrayRef[ ArrayRef[ Int | Undef ] ]');

ok $x->is_a_type_of('ArrayRef');
ok $x->is_a_type_of('ArrayRef[ArrayRef[Int|Undef]]');
ok!$x->is_a_type_of('ArrayRef[ArrayRef[Str]]');

ok $x->check([]);
ok $x->check([[]]);
ok $x->check([[10]]);
ok $x->check([[10, undef]]);
ok!$x->check([[10, 3.14]]);
ok!$x->check({});


