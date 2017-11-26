use strict;
use warnings;
use Test::More tests => 4;
{
    package Response;
    use Mouse;
    use Mouse::Util::TypeConstraints;

    use lib "t/lib";
    require ClassType_Foo;

    # XXX: This below API is different from that of Moose.
    # class_type() should be class_type 'ClassName';
    #    class_type 'Headers' => { class => 't::lib::ClassType_Foo' };
    # this should be subtype Headers => as 't::lib::ClassType_foo';
    subtype 'Headers'
        => as 'ClassType_Foo'
    ;
        
    coerce 'Headers' =>
        from 'HashRef' => via {
            ClassType_Foo->new(%{ $_ });
        },
    ;

    has headers => (
        is     => 'rw',
        isa    => 'Headers',
        coerce => 1,
    );
}

my $res = Response->new(headers => { foo => 'bar' });
isa_ok($res->headers, 'ClassType_Foo');
is($res->headers->foo, 'bar');
$res->headers({foo => 'yay'});
isa_ok($res->headers, 'ClassType_Foo');
is($res->headers->foo, 'yay');
