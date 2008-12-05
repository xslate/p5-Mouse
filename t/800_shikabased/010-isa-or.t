use strict;
use warnings;
use Test::More tests => 18;

{   
    package Foo;
    use Mouse;
    use Mouse::TypeRegistry;
    subtype Baz => where { defined($_) && $_ eq 'Baz' };
    coerce Baz => from 'ArrayRef', via { 'Baz' };
    has 'bar' => ( is => 'rw', isa => 'Str | Baz | Undef', coerce => 1 );
}

eval {
    Foo->new( bar => +{} );
};
ok $@, 'not got an object';

eval {
    isa_ok(Foo->new( bar => undef ), 'Foo');
};
ok !$@, 'got an object 1';

eval {
    isa_ok(Foo->new( bar => 'foo' ), 'Foo');

};
ok !$@, 'got an object 2';


my $f = Foo->new;
eval {
    $f->bar([]);
};
ok !$@;
is $f->bar, 'Baz', 'bar is baz (coerce from ArrayRef)';

eval {
    $f->bar('hoge');
};
ok !$@;
is $f->bar, 'hoge', 'bar is hoge';

eval {
    $f->bar(undef);
};
ok !$@;
is $f->bar, undef, 'bar is undef';


{   
    package Bar;
    use Mouse;
    use Mouse::TypeRegistry;

    subtype 'Type1' => where { defined($_) && $_ eq 'Name' };
    coerce 'Type1', from 'Str', via { 'Names' };

    subtype 'Type2' => where { defined($_) && $_ eq 'Group' };
    coerce 'Type2', from 'Str', via { 'Name' };

    has 'foo' => ( is => 'rw', isa => 'Type1|Type2', coerce => 1 );
}

my $foo = Bar->new( foo => 'aaa' );
ok $foo, 'got an object 3';
is $foo->foo, 'Name', 'foo is Name';


{
    package KLASS;
    sub new { bless {}, shift };
}
{   
    package Baz;
    use Mouse;
    use Mouse::TypeRegistry;

    subtype 'Type3' => where { defined($_) && $_ eq 'Name' };
    coerce 'Type3', from 'CodeRef', via { 'Name' };

    has 'foo' => ( is => 'rw', isa => 'Type3|KLASS|Undef', coerce => 1 );
}

eval { Baz->new( foo => 'aaa' ) };
like $@, qr/Attribute \(foo\) does not pass the type constraint because: Validation failed for 'Type3\|KLASS\|Undef' failed with value aaa/;

my $k = Baz->new;
ok $k, 'got an object 4';
$k->foo(sub {});
is $k->foo, 'Name', 'foo is Name';
$k->foo(KLASS->new);
isa_ok $k->foo, 'KLASS';
$k->foo(undef);
is $k->foo, undef, 'foo is undef';

