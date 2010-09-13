use strict;
use warnings;
use Test::More tests => 25;
use Test::Exception;

use Mouse ();

# error handling
throws_ok {
    Mouse::Meta::Class->create(
        "ClassName",
        superclasses => "foo"
    );
} qr/You must pass an ARRAY ref of superclasses/;


throws_ok {
    Mouse::Meta::Class->create(
        "ClassName",
        attributes => "foo"
    );
} qr/You must pass an ARRAY ref of attributes/;

throws_ok {
    Mouse::Meta::Class->create(
        "ClassName",
        methods => "foo"
    );
} qr/You must pass a HASH ref of methods/;

# normal cases
isa_ok(Mouse::Meta::Class->create("FooBar"), "Mouse::Meta::Class");
is FooBar->meta->name, "FooBar";

isa_ok(
    Mouse::Meta::Class->create(
        "Baz",
        superclasses => [ "FooBar", "Mouse::Object" ],
        attributes   => [
            Mouse::Meta::Attribute->new(
                "foo" => (
                    is => "rw",
                    default => "yay",
                ),
            )
        ],
        methods => {
            dooo => sub { "iiiit" },
        }
    ),
    "Mouse::Meta::Class"
);
isa_ok Baz->new(), "FooBar";
is Baz->new()->foo, "yay";
is Baz->new()->dooo, "iiiit";

my($anon_pkg1, $anon_pkg2);
{
    my $meta = Mouse::Meta::Class->create_anon_class(
        superclasses => [ "Mouse::Object" ],
        methods => {
            dooo => sub { "iiiit" },
        }
    );
    $anon_pkg1 = $meta->name;

    isa_ok($meta, "Mouse::Meta::Class", 'create_anon_class');
    ok($meta->is_anon_class, 'is_anon_class');
    is $meta->name->new->dooo(), "iiiit";

    my $anon2 = Mouse::Meta::Class->create_anon_class(cache => 1);
    $anon_pkg2 = $anon2->name;

    ok($anon2->is_anon_class);

    isnt $meta, $anon2;
    isnt $meta->name, $anon2->name;
}

# all the stuff are removed?
ok !$anon_pkg1->isa('Mouse::Object');
ok !$anon_pkg1->can('dooo');
ok !$anon_pkg1->can('meta');

ok $anon_pkg2->can('meta'), 'cache => 1 makes it immortal';

my $anon = Mouse::Meta::Class->create_anon_class(
    constructor_class => 'ConstructorX',
    destructor_class  => 'DestructorX',
);

is $anon->constructor_class, 'ConstructorX';
is $anon->destructor_class,  'DestructorX';

my $obj;
{
    my $anon = Mouse::Meta::Class->create_anon_class(superclasses => ['Mouse::Object']);
    lives_ok{ $anon->make_immutable() } 'make anon class immutable';
    $obj = $anon->name->new();
}

SKIP:{
    skip 'Moose has a bug', 3 if 'Mouse' eq 'Moose';

    isa_ok $obj, 'Mouse::Object';
    can_ok $obj, 'meta';
    lives_and{
        isa_ok $obj->meta, 'Mouse::Meta::Class';
    };
}
