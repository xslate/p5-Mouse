#!perl

# XXX:
# XXX: !!!Currently this test is not compatible with Moose!!!
# XXX:

use strict;
use warnings;
use Test::More tests => 22;

{   
    package Foo;
    use Mouse;
    use Mouse::Util::TypeConstraints;
    type Baz => where { defined($_) && $_ eq 'Baz' };

    coerce Baz => from 'ArrayRef', via { 'Baz' };

    has 'bar' => ( is => 'rw', isa => 'Str | Baz | Undef', coerce => 1 );
}

eval {
    Foo->new( bar => +{} );
};
like($@, qr/^Attribute \(bar\) does not pass the type constraint because: Validation failed for 'Baz\|Str\|Undef' with value HASH\(\w+\)/, 'type constraint and coercion failed')
    or diag "\$@='$@'";

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
ok !$@, $@;
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
    use Mouse::Util::TypeConstraints;

    type 'Type1' => where { defined($_) && $_ eq 'Name' };
    coerce 'Type1', from 'Str', via { 'Names' };

    type 'Type2' => where { defined($_) && $_ eq 'Group' };
    coerce 'Type2', from 'Str', via { 'Name' };

    has 'foo' => ( is => 'rw', isa => 'Type1|Type2', coerce => 1 );
}

my $foo = Bar->new( foo => 'aaa' );
ok $foo, 'got an object 3';
is $foo->foo, 'Name', 'foo is Name';


{
    package KLASS;
    use Mouse;
}
{   
    package Funk;
    use Mouse;
    use Mouse::Util::TypeConstraints;

    type 'Type3' => where { defined($_) && $_ eq 'Name' };
    coerce 'Type3', from 'CodeRef', via { 'Name' };

    has 'foo' => ( is => 'rw', isa => 'Type3|KLASS|Undef', coerce => 1 );
}

eval { Funk->new( foo => 'aaa' ) };
like $@, qr/Attribute \(foo\) does not pass the type constraint because: Validation failed for 'KLASS\|Type3\|Undef' with value aaa/;

my $k = Funk->new;
ok $k, 'got an object 4';
$k->foo(sub {});
is $k->foo, 'Name', 'foo is Name';
$k->foo(KLASS->new);
isa_ok $k->foo, 'KLASS';
$k->foo(undef);
is $k->foo, undef, 'foo is undef';

# or-combination operator ('|')
{
    use Mouse::Util::TypeConstraints;
    my $Int    = find_type_constraint 'Int';
    my $Str    = find_type_constraint 'Str';
    my $Object = find_type_constraint 'Object';

    *t = \&Mouse::Util::TypeConstraints::find_or_parse_type_constraint; # alias

    is $Int | $Str, t('Int | Str');
    is $Str | $Int, t('Int | Str');

    is $Int | $Str | $Object, t('Int | Str | Object');
    is $Str | $Object | $Int, t('Int | Str | Object');
}

