use strict;
use warnings;
use Test::More tests => 13;

{
    package Types;
    use strict;
    use warnings;
    use MouseX::Types -declare => [qw/ Baz Type1 Type2 /];
    use MouseX::Types::Mouse qw( ArrayRef );

    type Baz, where { defined($_) && $_ eq 'Baz' };
    coerce Baz, from ArrayRef, via { 'Baz' };

    type Type1, where { defined($_) && $_ eq 'Name' };
    coerce Type1, from 'Str', via { 'Names' };

    type Type2, where { defined($_) && $_ eq 'Group' };
    coerce Type2, from 'Str', via { 'Name' };

}

{   
    package Foo;
    use Mouse;
    use MouseX::Types::Mouse qw( Str Undef );
    BEGIN { Types->import(qw( Baz Type1 )) }
    has 'bar' => ( is => 'rw', isa => Str | Baz | Undef, coerce => 1 );
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
    BEGIN { Types->import(qw( Type1 Type2 )) }
    has 'foo' => ( is => 'rw', isa => Type1 | Type2 , coerce => 1 );
}

my $foo = Bar->new( foo => 'aaa' );
ok $foo, 'got an object 3';
is $foo->foo, 'Name', 'foo is Name';
