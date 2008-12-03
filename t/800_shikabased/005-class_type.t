use strict;
use warnings;
use Test::More tests => 4;

{
    package Response::Headers;
    use Mouse;
    has 'foo' => ( is => 'rw' );
}

{
    package Response;
    use Mouse;
    use Mouse::TypeRegistry;

    class_type Headers => { class => 'Response::Headers' };
    coerce 'Headers' =>
        from 'HashRef' => via {
            Response::Headers->new(%{ $_ });
        },
    ;

    has headers => (
        is     => 'rw',
        isa    => 'Headers',
        coerce => 1,
    );
}

my $res = Response->new(headers => { foo => 'bar' });
isa_ok($res->headers, 'Response::Headers');
is($res->headers->foo, 'bar');
$res->headers({foo => 'yay'});
isa_ok($res->headers, 'Response::Headers');
is($res->headers->foo, 'yay');
