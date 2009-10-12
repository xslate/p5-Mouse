use strict;
use warnings;
use Test::More tests => 5;

{
    package Animal;
    use Mouse::Role;
    requires 'bark';
    sub eat { 'delicious' }
    has food => ( is => 'ro' );
}

{
    package Dog;
    use Mouse::Role;
    with 'Animal';
}

{
    package Chihuahua;
    use Mouse;
    with 'Dog';
    sub bark { 'bow-wow' }
}

ok !Animal->can('food');
ok !Dog->can('food');

my $c = Chihuahua->new(food => 'bone');
is $c->eat(), 'delicious';
is $c->food(), 'bone';
is $c->bark(), 'bow-wow';

