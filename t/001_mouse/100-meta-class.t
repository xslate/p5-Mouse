#!/usr/bin/env perl
use strict;
use warnings;
use Test::More;
use Test::Exception;
{
    package Class;
    use Mouse;
    use Scalar::Util qw(blessed weaken); # import external functions

    has pawn => (
        is        => 'rw',
        predicate => 'has_pawn',
    );

    use constant MY_CONST => 42;

    sub stub;
    sub stub_with_attr :method;

    sub king { 'king' }

    no Mouse;
}
{
    package Child;
    use Mouse;
    use Carp qw(carp croak); # import extenral functions

    extends 'Class';

    has bishop => (
        is => 'rw',
    );

    sub child_method{ }
}

my $meta = Class->meta;
isa_ok($meta, 'Mouse::Meta::Class');

is_deeply([$meta->superclasses], ['Mouse::Object'], "correctly inherting from Mouse::Object");

my $meta2 = Class->meta;
is($meta, $meta2, "same metaclass instance");

can_ok($meta, qw(
    name meta
    has_attribute get_attribute get_attribute_list get_all_attributes
    has_method    get_method    get_method_list    get_all_methods
));

ok($meta->has_attribute('pawn'));
my $attr = $meta->get_attribute('pawn');
isa_ok($attr, 'Mouse::Meta::Attribute');
is($attr->name, 'pawn', 'got the correct attribute');

my $list = [$meta->get_attribute_list];
is_deeply($list, [ 'pawn' ], "attribute list");

ok(!$meta->has_attribute('nonexistent_attribute'));

ok($meta->has_method('pawn'));
lives_and{
    my $pawn = $meta->get_method('pawn');
    ok($pawn);
    is($pawn->name, 'pawn');
    is($pawn->package_name, 'Class');
    is($pawn->fully_qualified_name, 'Class::pawn');

    is $pawn, $pawn;

    my $king = $meta->get_method('king');
    isnt $pawn, $king;

    $meta->add_method(king => sub{ 'fool' });
    isnt $king, $meta->get_method('king');
};

is( join(' ', sort $meta->get_method_list),
    join(' ', sort qw(meta pawn king has_pawn MY_CONST stub stub_with_attr))
);

eval q{
    package Class;
    use Mouse;
    no Mouse;
};

my $meta3 = Class->meta;
is($meta, $meta3, "same metaclass instance, even if use Mouse is performed again");

is($meta->name, 'Class', "name for the metaclass");


my $child_meta = Child->meta;
isa_ok($child_meta, 'Mouse::Meta::Class');

isnt($meta, $child_meta, "different metaclass instances for the two classes");

is_deeply([$child_meta->superclasses], ['Class'], "correct superclasses");


ok($child_meta->has_attribute('bishop'));
ok($child_meta->has_method('child_method'));


is( join(' ', sort $child_meta->get_method_list),
    join(' ', sort qw(meta bishop child_method))
);

can_ok($child_meta, 'find_method_by_name');
is $child_meta->find_method_by_name('child_method')->fully_qualified_name, 'Child::child_method';
is $child_meta->find_method_by_name('pawn')->fully_qualified_name,         'Class::pawn';


is( join(' ', sort map{ $_->fully_qualified_name } grep{ $_->package_name ne 'Mouse::Object' } $child_meta->get_all_methods),
    join(' ', sort qw(
        Child::bishop Child::child_method Child::meta

        Class::MY_CONST Class::has_pawn Class::pawn Class::king Class::stub Class::stub_with_attr
    ))
);

done_testing;

