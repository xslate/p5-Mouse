use strict;
use warnings;
use Test::More tests => 4;
{
    package Response;
    use Mouse;
    use Mouse::Util::TypeConstraints;

    require t::lib::ClassType_Foo;

    class_type Headers => { class => 't::lib::ClassType_Foo' };
    coerce 'Headers' =>
        from 'HashRef' => via {
            t::lib::ClassType_Foo->new(%{ $_ });
        },
    ;

    has headers => (
        is     => 'rw',
        isa    => 'Headers',
        coerce => 1,
    );
}

my $res = Response->new(headers => { foo => 'bar' });
isa_ok($res->headers, 't::lib::ClassType_Foo');
is($res->headers->foo, 'bar');
$res->headers({foo => 'yay'});
isa_ok($res->headers, 't::lib::ClassType_Foo');
is($res->headers->foo, 'yay');
