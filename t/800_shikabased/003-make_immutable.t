use strict;
use warnings;
use Test::More tests => 6;
use Test::Exception;

{
    package HardDog;
    use Mouse;
    has bone => (
        is => 'rw',
        required => 1,
    );
    sub BUILD { main::ok "calling BUILD in HardDog" }
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
    sub BUILD { main::ok "calling BUILD in SoftDog" }
    no Mouse;
}

lives_ok { SoftDog->new(bone => 'moo') };
lives_ok { HardDog->new(bone => 'moo') };

throws_ok { SoftDog->new() } qr/\QAttribute (bone) is required/;
throws_ok { HardDog->new() } qr/\QAttribute (bone) is required/;

