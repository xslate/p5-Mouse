#!perl
use strict;
use warnings;
use Test::More;
use Test::Exception;

use Config;
use Tie::Hash;
use Tie::Array;

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
    } qr/Attribute \(foo\) does not pass the type constraint because: Validation failed for 'HashRef\[Int\]' with value/, "Bad args for hash throws an exception";

    throws_ok {
        Foo->new( bar => [ a => 'b' ]);
    } qr/Attribute \(bar\) does not pass the type constraint because: Validation failed for 'ArrayRef\[Int\]' with value/, "Bad args for array throws an exception";

    throws_ok {
        Foo->new( complex => [ { a => 1, b => 1 }, { c => "d", e => "f" } ] )
    } qr/Attribute \(complex\) does not pass the type constraint because: Validation failed for 'ArrayRef\[HashRef\[Int\]\]' with value/, "Bad args for complex types throws an exception";

    throws_ok {
        Foo->new( my_class => [ 10 ] );
    } qr/Attribute \(my_class\) does not pass the type constraint because: Validation failed for 'ArrayRef\[My::Class\]' with value/;
    throws_ok {
        Foo->new( my_class => [ {foo => 'bar'} ] );
    } qr/Attribute \(my_class\) does not pass the type constraint because: Validation failed for 'ArrayRef\[My::Class\]' with value/;


    throws_ok {
        Foo->new( my_role => [ 20 ] );
    } qr/Attribute \(my_role\) does not pass the type constraint because: Validation failed for 'ArrayRef\[My::Role\]' with value/;
    throws_ok {
        Foo->new( my_role => [ {foo => 'bar'} ] );
    } qr/Attribute \(my_role\) does not pass the type constraint because: Validation failed for 'ArrayRef\[My::Role\]' with value/;
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
    } "coercion works"
        or diag( Mouse::Util::TypeConstraints::find_type_constraint("Bar::List")->dump );

    throws_ok {
        Bar->new(list => [ { 1 => 2 }, 2, 3 ]);
    } qr/Attribute \(list\) does not pass the type constraint because: Validation failed for 'Bar::List' with value/, "Bad coercion parameter throws an error";
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

$x = tie my @ta, 'Tie::StdArray';

my $array_of_int = Mouse::Util::TypeConstraints::find_or_parse_type_constraint('ArrayRef[Int]');

@$x = (1, 2, 3);
ok $array_of_int->check(\@ta), 'magical array';

@$x = (1, 2, 3.14);
ok !$array_of_int->check(\@ta);

$x = tie my %th, 'Tie::StdHash';

my $hash_of_int = Mouse::Util::TypeConstraints::find_or_parse_type_constraint('HashRef[Int]');

%$x = (foo => 1, bar => 3, baz => 5);
ok $hash_of_int->check(\%th), 'magical hash';

$x->{foo} = 3.14;
ok!$hash_of_int->check(\%th);

my %th_clone;
while(my($k, $v) = each %th){
    $th_clone{$k} = $v;
}

is( $hash_of_int->type_parameter, 'Int' );

if('Mouse' eq ('Mo' . 'use')){ # under Mouse
    ok $hash_of_int->__is_parameterized();
    ok!$hash_of_int->type_parameter->__is_parameterized();
}
else{ # under Moose
    ok $hash_of_int->can('type_parameter');
    ok!$hash_of_int->type_parameter->can('type_parameter');
}

is_deeply \%th_clone, \%th, 'the hash iterator is initialized';


for my $i(1 .. 2) {
    note "derived from parameterized types #$i";

    my $myhashref = subtype 'MyHashRef',
        as 'HashRef[Value]',
        where { keys %$_ > 1 };

    ok  $myhashref->is_a_type_of('HashRef'), "$myhashref";
    ok  $myhashref->check({ a => 43, b => 100 });
    ok  $myhashref->check({ a => 43, b => 3.14 });
    ok !$myhashref->check({});
    ok !$myhashref->check({ a => 42, b => [] });

    is $myhashref->type_parameter, 'Value';

    $myhashref = subtype 'H', as 'MyHashRef[Int]';

    ok  $myhashref->is_a_type_of('HashRef'), "$myhashref";
    ok  $myhashref->check({ a => 43, b => 100 });
    ok  $myhashref->check({ a => 43, b => 100, c => 0 });
    ok !$myhashref->check({}), 'empty hash';
    ok !$myhashref->check({ foo => 42 });
    {
        local $TODO = 'See https://rt.cpan.org/Ticket/Display.html?id=71211'
            if $Config{archname} =~ /\A ia64 /xmsi;

        ok !$myhashref->check({ a => 43, b => "foo" }) or eval {
            require Data::Dump::Streamer;
            my $s = Data::Dump::Streamer::Dump($myhashref)->Out();
            $s =~ s/[ ]{4}/ /g;
            note $s;
        };
    }
    ok !$myhashref->check({ a => 42, b => [] });
    ok !$myhashref->check({ a => 42, b => undef });
    ok !$myhashref->check([42]);
    ok !$myhashref->check("foo");

    is $myhashref->type_parameter, 'Int';
}

done_testing;

