use strict;
use warnings;
use Test::More;

{
    package Request::Headers::Role;
    use Mouse::Role;
    has 'foo' => ( is => 'rw' );
}

{
    package Request::Headers;
    use Mouse;
    with 'Request::Headers::Role';
}

{
    package Response::Headers::Role;
    use Mouse::Role;
    has 'foo' => ( is => 'rw' );
}

{
    package Response::Headers;
    use Mouse;
    with 'Response::Headers::Role';
}

{
    package Response;
    use Mouse;
    use Mouse::Util::TypeConstraints;

    role_type Headers => { role => 'Response::Headers::Role' };
    coerce 'Headers' =>
        from 'HashRef' => via {
            Response::Headers->new(%{ $_ });
        },
    ;

    has headers => (
        is     => 'rw',
        does   => 'Headers',
        coerce => 1,
    );
}

my $res = Response->new(headers => { foo => 'bar' });
isa_ok($res->headers, 'Response::Headers');
is($res->headers->foo, 'bar');
$res->headers({foo => 'yay'});
isa_ok($res->headers, 'Response::Headers');
is($res->headers->foo, 'yay');

eval {
    $res->headers( Request::Headers->new( foo => 'baz' ) );
};
like $@, qr/Validation failed/;

eval {
    $res->headers( Request::Headers->new( foo => undef ) );
};
like $@, qr/Validation failed/;

done_testing;

