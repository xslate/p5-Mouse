use strict;
use warnings;
use Test::More tests => 2;
use Mouse::Util::TypeConstraints;

subtype 'Foo', where => sub { $_->isa('A') };

{
    package A;
    use Mouse;
    has data => ( is => 'rw', isa => 'Str' );
}

{
    package B;
    use Mouse;
    has a => ( is => 'rw', isa => 'Foo', coerce => 1 );
}

isa_ok(B->new(a => A->new()), 'B');
B->meta->make_immutable;
isa_ok(B->new(a => A->new()), 'B');

