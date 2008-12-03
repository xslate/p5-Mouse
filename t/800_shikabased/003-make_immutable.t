use strict;
use warnings;
use Test::More tests => 4;
use t::Exception;

{
    package HardDog;
    use Mouse;
    has bone => (
        is => 'rw',
        required => 1,
    );
    no Mouse;
    __PACKAGE__->meta->make_immutable;
}

{
    package SoftDog;
    use Mouse;
    has bone => (
        is => 'rw',
        required => 1,
    );
    no Mouse;
}

lives_ok { SoftDog->new(bone => 'moo') };
lives_ok { HardDog->new(bone => 'moo') };

throws_ok { SoftDog->new() } qr/\QAttribute (bone) is required/;
throws_ok { HardDog->new() } qr/\QAttribute (bone) is required/;

