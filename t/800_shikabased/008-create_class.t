use strict;
use warnings;
use Mouse ();
use Test::More tests => 14;
use Test::Exception;

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


throws_ok {
    Mouse::Meta::Class->create()
} qr/You must pass a package name/;

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

{
    my $meta = Mouse::Meta::Class->create_anon_class(
        superclasses => [ "Mouse::Object" ],
        methods => {
            dooo => sub { "iiiit" },
        }
    );
    isa_ok($meta, "Mouse::Meta::Class");
    like($meta->name, qr/Class::__ANON__::/);
    is $meta->name->new->dooo(), "iiiit";

    my $anon2 = Mouse::Meta::Class->create_anon_class();
    like($anon2->name, qr/Class::__ANON__::/);
}
