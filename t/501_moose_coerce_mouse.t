#!/usr/bin/perl

use strict;
use warnings;

use Test::More;
use t::Exception;
BEGIN {
    plan skip_all => "Moose required for this test" unless eval { require Moose  && Moose->VERSION('0.59') };
    plan tests => 5;
}

use t::Exception;

{
    package Headers;
    use Mouse;
    has 'foo' => ( is => 'rw' );
}
{
    package Response;
    use Mouse;
    use Mouse::TypeRegistry;

    subtype 'HeadersType' => sub { defined $_ && eval { $_->isa('Headers') } };
    coerce 'HeadersType' => +{
        HashRef => sub {
            Headers->new(%{ $_ });
        },
    };

    has headers => (
        is     => 'rw',
        isa    => 'HeadersType',
        coerce => 1,
    );
}
{
    package Mosponse;
    use Moose;
    extends qw(Response);
    ::lives_ok { extends qw(Response) } "extend Mouse class with Moose";
}

{
    my $r = Mosponse->new(headers => { foo => 'bar' });
    local our $TODO = "Moose not yet aware of Mouse meta";
    isa_ok($r->headers, 'Headers');
    is(eval{$r->headers->foo}, 'bar');
    $r->headers({foo => 'yay'});
    isa_ok($r->headers, 'Headers');
    is($r->headers->foo, 'yay');
}
