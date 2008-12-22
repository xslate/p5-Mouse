use strict;
use warnings;
use Test::More tests => 16;

{
    package Types;
    use MouseX::Types -declare => [qw/ Headers /];
    use MouseX::Types::Mouse 'HashRef';

    type Headers, where { defined $_ && eval { $_->isa('Headers1') } };
    coerce Headers,
        from HashRef, via {
            Headers1->new(%{ $_ });
        },
    ;
}

{
    package Types2;
    use MouseX::Types -declare => [qw/ Headers /];
    use MouseX::Types::Mouse 'HashRef';

    type Headers, where { defined $_ && eval { $_->isa('Headers2') } };
    coerce Headers,
        from HashRef, via {
            Headers2->new(%{ $_ });
        },
    ;
}

{
    package Headers1;
    use Mouse;
    has 'foo' => ( is => 'rw' );
}

{
    package Headers2;
    use Mouse;
    has 'foo' => ( is => 'rw' );
}

{
    package Response;
    use Mouse;
    BEGIN { Types->import(qw/ Headers /) }

    has headers => (
        is     => 'rw',
        isa    => Headers,
        coerce => 1,
    );
}

{
    package Request;
    use Mouse;
    BEGIN { Types->import(qw/ Headers /) }

    has headers => (
        is     => 'rw',
        isa    => Headers,
        coerce => 1,
    );
}

{
    package Response2;
    use Mouse;
    BEGIN { Types2->import(qw/ Headers /) }

    has headers => (
        is     => 'rw',
        isa    => Headers,
        coerce => 1,
    );
}

{
    package Request2;
    use Mouse;
    BEGIN { Types2->import(qw/ Headers /) }

    has headers => (
        is     => 'rw',
        isa    => Headers,
        coerce => 1,
    );
}

my $res = Response->new(headers => { foo => 'bar' });
isa_ok($res->headers, 'Headers1');
is($res->headers->foo, 'bar');
$res->headers({foo => 'yay'});
isa_ok($res->headers, 'Headers1');
is($res->headers->foo, 'yay');

my $req = Request->new(headers => { foo => 'bar' });
isa_ok($res->headers, 'Headers1');
is($req->headers->foo, 'bar');
$req->headers({foo => 'yay'});
isa_ok($res->headers, 'Headers1');
is($req->headers->foo, 'yay');

$res = Response2->new(headers => { foo => 'bar' });
isa_ok($res->headers, 'Headers2');
is($res->headers->foo, 'bar');
$res->headers({foo => 'yay'});
isa_ok($res->headers, 'Headers2');
is($res->headers->foo, 'yay');

$req = Request2->new(headers => { foo => 'bar' });
isa_ok($res->headers, 'Headers2');
is($req->headers->foo, 'bar');
$req->headers({foo => 'yay'});
isa_ok($res->headers, 'Headers2');
is($req->headers->foo, 'yay');

