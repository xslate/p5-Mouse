#!/usr/bin/perl

use strict;
use warnings;

use Test::More;
use Test::Exception;
use Scalar::Util qw(refaddr);

BEGIN {
    use_ok('Mouse::Util::TypeConstraints');
}

# subtype 'aliasing' ...

lives_ok {
    subtype 'Numb3rs' => as 'Num';
} '... create bare subtype fine';

my $numb3rs = find_type_constraint('Numb3rs');
isa_ok($numb3rs, 'Mouse::Meta::TypeConstraint');

# subtype with unions

{
    package Test::Mouse::Meta::TypeConstraint::Union;

    use overload '""' => sub {'Broken|Test'}, fallback => 1;
    use Mouse;

    extends 'Mouse::Meta::TypeConstraint';
}

my $dummy_instance = Test::Mouse::Meta::TypeConstraint::Union->new;

ok $dummy_instance => "Created Instance";

isa_ok $dummy_instance,
    'Test::Mouse::Meta::TypeConstraint::Union' => 'isa correct type';

is "$dummy_instance", "Broken|Test" =>
    'Got expected stringification result';

my $subtype1 = subtype 'New1' => as $dummy_instance;

ok $subtype1 => 'made a subtype from our type object';

my $subtype2 = subtype 'New2' => as $subtype1;

ok $subtype2 => 'made a subtype of our subtype';

# assert_valid

{
    my $type = find_type_constraint('Num');

    my $ok_1 = eval { $type->assert_valid(1); };
    ok($ok_1, "we can assert_valid that 1 is of type $type");

    my $ok_2 = eval { $type->assert_valid('foo'); };
    my $error = $@;
    ok(! $ok_2, "'foo' is not of type $type");
    like(
        $error,
        qr{validation failed for .\Q$type\E.}i,
        "correct error thrown"
    );
}

{
    for my $t (qw(Bar Foo)) {
        my $tc = Mouse::Meta::TypeConstraint->new({
            name => $t,
        });

        Mouse::Util::TypeConstraints::register_type_constraint($tc);
    }

    my $foo = Mouse::Util::TypeConstraints::find_type_constraint('Foo');
    my $bar = Mouse::Util::TypeConstraints::find_type_constraint('Bar');

    ok(!$foo->is_a_type_of($bar), "Foo type is not equal to Bar type");
    ok( $foo->is_a_type_of($foo), "Foo equals Foo");
    ok( 0+$foo == refaddr($foo), "overloading works");
}

ok $subtype1, "type constraint boolean overload works";

done_testing;
