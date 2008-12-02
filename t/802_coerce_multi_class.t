use strict;
use warnings;
use Test::More tests => 8;

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

    subtype 'Headers' => sub { defined $_ && eval { $_->isa('Response::Headers') } };
    coerce 'Headers' => +{
        HashRef => sub {
            Response::Headers->new(%{ $_ });
        },
    };

    has headers => (
        is     => 'rw',
        isa    => 'Headers',
        coerce => 1,
    );
}

{
    package Request;
    use Mouse;
    use Mouse::TypeRegistry;

    subtype 'Headers' => sub { defined $_ && eval { $_->isa('Request::Headers') } };
    coerce 'Headers' => +{
        HashRef => sub {
            Request::Headers->new(%{ $_ });
        },
    };

    has headers => (
        is     => 'rw',
        isa    => 'Headers',
        coerce => 1,
    );
}

{
    package Response;
    subtype 'Headers' => sub { defined $_ && eval { $_->isa('Response::Headers') } };
    coerce 'Headers' => +{
        HashRef => sub {
            Response::Headers->new(%{ $_ });
        },
    };
}

my $req = Request->new(headers => { foo => 'bar' });
isa_ok($req->headers, 'Request::Headers');
is($req->headers->foo, 'bar');
$req->headers({foo => 'yay'});
isa_ok($req->headers, 'Request::Headers');
is($req->headers->foo, 'yay');

my $res = Response->new(headers => { foo => 'bar' });
isa_ok($res->headers, 'Response::Headers');
is($res->headers->foo, 'bar');
$res->headers({foo => 'yay'});
isa_ok($res->headers, 'Response::Headers');
is($res->headers->foo, 'yay');
