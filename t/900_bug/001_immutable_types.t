use strict;
use warnings;
use Test::More tests => 2;
use Mouse::Util::TypeConstraints;

subtype 'Foo', as 'Object', where { $_->isa('A') };

{
    package A;
    use Mouse;
    has data => ( is => 'rw', isa => 'Str' );
}

{
    package C;
    use Mouse;
    has a => ( is => 'rw', isa => 'Foo', coerce => 1 );
}

isa_ok(C->new(a => A->new()), 'C');
C->meta->make_immutable;
isa_ok(C->new(a => A->new()), 'C');

