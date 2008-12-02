use strict;
use warnings;
use Test::More tests => 4;

{
    package Animal;
    use Mouse::Role;
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
}

ok !Animal->can('food');
ok !Dog->can('food');

my $c = Chihuahua->new(food => 'bone');
is $c->eat(), 'delicious';
is $c->food(), 'bone';

