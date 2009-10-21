use strict;
use warnings;
use Test::More tests => 6;

{
    package Headers;
    use Mouse;
    has 'foo' => ( is => 'rw' );
}

{
    package Response;
    use Mouse;
    use Mouse::Util::TypeConstraints;

    subtype 'HeadersType' => as 'Object' => where { $_->isa('Headers') };
    coerce 'HeadersType' =>
        from 'ScalarRef' => via {
            Headers->new();
        },
        from 'HashRef' => via {
            Headers->new(%{ $_ });
        }
    ;

    has headers => (
        is     => 'rw',
        isa    => 'HeadersType',
        coerce => 1,
    );
    has lazy_build_coerce_headers => (
        is     => 'rw',
        isa    => 'HeadersType',
        coerce => 1,
        lazy_build => 1,
    );
    sub _build_lazy_build_coerce_headers {
        Headers->new(foo => 'laziness++')
    }
    has lazy_coerce_headers => (
        is     => 'rw',
        isa    => 'HeadersType',
        coerce => 1,
        lazy => 1,
        default => sub { Headers->new(foo => 'laziness++') }
    );
}

my $r = Response->new(headers => { foo => 'bar' });
isa_ok($r->headers, 'Headers');
is($r->headers->foo, 'bar');
$r->headers({foo => 'yay'});
isa_ok($r->headers, 'Headers');
is($r->headers->foo, 'yay');
is($r->lazy_coerce_headers->foo, 'laziness++');
is($r->lazy_build_coerce_headers->foo, 'laziness++');

