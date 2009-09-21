#!/usr/bin/perl

use strict;
use warnings;

use Test::More;
use Test::Exception;
BEGIN {
    my $require_version = 0.68;
    plan skip_all => "Moose $require_version required for this test" unless eval { require Moose  && Moose->VERSION($require_version) };
    plan tests => 5;
}

use Test::Exception;

{
    package Headers;
    use Mouse;
    has 'foo' => ( is => 'rw' );
}
{
    package Response;
    use Mouse;
    use Mouse::Util::TypeConstraints;

    type 'HeadersType' => where { defined $_ && eval { $_->isa('Headers') } };
    coerce  'HeadersType' =>
        from 'HashRef' => via {
            Headers->new(%{ $_ });
        },
    ;

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
    isa_ok($r->headers, 'Headers');
    lives_and {
        is $r->headers->foo, 'bar';
    };
}

{
    my $r = Mosponse->new;
    $r->headers({foo => 'yay'});
    isa_ok($r->headers, 'Headers');
    is($r->headers->foo, 'yay');
}
