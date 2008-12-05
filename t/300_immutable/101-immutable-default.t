use strict;
use warnings;

use Test::More tests => 5;
use Test::Exception;

{
    package Foo;
    use Mouse;

    #two checks because the inlined methods are different when
    #there is a TC present.
    has 'foos' => ( is => 'rw', default => 'DEFAULT' );
    has 'bars' => ( is => 'rw', default => 300100 );
    has 'bazs' => ( is => 'rw', default => sub { +{} } );

}

lives_ok { Foo->meta->make_immutable }
    'Immutable meta with single BUILD';

my $f = Foo->new;
isa_ok $f, 'Foo';
is $f->foos, 'DEFAULT', 'str default';
is $f->bars, 300100, 'int default';
is ref($f->bazs), 'HASH', 'code default';

