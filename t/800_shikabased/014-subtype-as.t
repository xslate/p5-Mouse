use strict;
use warnings;
use Test::More tests => 6;
use Scalar::Util qw/blessed/;

{
    package Obj1;
    sub new { bless {}, shift };
}
{
    package Obj2;
    use overload '""' => sub { 'Ref' }, fallback => 1;
    sub new { bless {}, shift };
}

{
    package Foo;
    use Mouse;
    use Mouse::TypeRegistry;

    subtype 'Type1' => as 'Str' => where { blessed($_) };
    has str_obj => (
        is     => 'rw',
        isa    => 'Type1',
    );

    subtype 'Type2' => as 'Object' => where { $_ eq 'Ref' };
    has obj_str => (
        is     => 'rw',
        isa    => 'Type2',
    );
}

eval { Foo->new( str_obj => Obj1->new ) };
like $@, qr/Attribute \(str_obj\) does not pass the type constraint because: Validation failed for 'Type1' failed with value Obj1=HASH/;
eval { Foo->new( obj_str => Obj1->new ) };
like $@, qr/Attribute \(obj_str\) does not pass the type constraint because: Validation failed for 'Type2' failed with value Obj1=HASH/;

eval { Foo->new( str_obj => Obj2->new ) };
like $@, qr/Attribute \(str_obj\) does not pass the type constraint because: Validation failed for 'Type1' failed with value Obj2=HASH/;

eval { Foo->new( str_obj => 'Ref' ) };
like $@, qr/Attribute \(str_obj\) does not pass the type constraint because: Validation failed for 'Type1' failed with value Ref/;

my $f1 = eval { Foo->new( obj_str => Obj2->new ) };
isa_ok $f1, 'Foo';
is $f1->obj_str, 'Ref';
