use strict;
use warnings;
use Test::More tests => 14;

{
    package Response::Headers;
    use Mouse;
    has 'foo' => ( is => 'rw' );
}
{
    package Request::Headers;
    use Mouse;
    has 'foo' => ( is => 'rw' );
}

{
    package Response;
    use Mouse;
    use Mouse::TypeRegistry;

    subtype 'Headers' => where { defined $_ && eval { $_->isa('Response::Headers') } };
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

eval {
    package Request;
    use Mouse::TypeRegistry;

    subtype 'Headers' => where { defined $_ && eval { $_->isa('Request::Headers') } };
};
like $@, qr/The type constraint 'Headers' has already been created, cannot be created again in Request/;

eval {
    package Request;
    use Mouse::TypeRegistry;

    coerce 'TooBad' =>
        from 'HashRef' => via {
            Request::Headers->new(%{ $_ });
        },
    ;
};
like $@, qr/Cannot find type 'TooBad', perhaps you forgot to load it./;

eval {
    package Request;
    use Mouse::TypeRegistry;

    coerce 'Headers' =>
        from 'HashRef' => via {
            Request::Headers->new(%{ $_ });
        },
    ;
};
like $@, qr/A coercion action already exists for 'HashRef'/;

eval {
    package Request;
    use Mouse::TypeRegistry;

    coerce 'Headers' =>
        from 'HashRefa' => via {
            Request::Headers->new(%{ $_ });
        },
    ;
};
like $@, qr/Could not find the type constraint \(HashRefa\) to coerce from/;

eval {
    package Request;
    use Mouse::TypeRegistry;

    coerce 'Headers' =>
        from 'ArrayRef' => via {
            Request::Headers->new(%{ $_ });
        },
    ;
};
ok !$@;

eval {
    package Response;
    subtype 'Headers' => where { defined $_ && eval { $_->isa('Response::Headers') } };
};
like $@, qr/The type constraint 'Headers' has already been created, cannot be created again in Response/;

{
    package Request;
    use Mouse;

    has headers => (
        is     => 'rw',
        isa    => 'Headers',
        coerce => 1,
    );
}


my $req = Request->new(headers => { foo => 'bar' });
isa_ok($req->headers, 'Response::Headers');
is($req->headers->foo, 'bar');
$req->headers({foo => 'yay'});
isa_ok($req->headers, 'Response::Headers');
is($req->headers->foo, 'yay');

my $res = Response->new(headers => { foo => 'bar' });
isa_ok($res->headers, 'Response::Headers');
is($res->headers->foo, 'bar');
$res->headers({foo => 'yay'});
isa_ok($res->headers, 'Response::Headers');
is($res->headers->foo, 'yay');
