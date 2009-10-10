use strict;
use warnings;
use Test::More tests => 6;

{
    package Animal;
    use Mouse::Role;
    sub eat { 'delicious' }
}

{
    package Cat;
    use Mouse::Role;
    with 'Animal', {
        -alias    => { eat => 'drink' },
        -excludes => [qw(eat)],
    };
    sub eat { 'good!' }
}

{
    package Tama;
    use Mouse;
    with 'Cat';
}

{
    package Dog;
    use Mouse;
    with 'Animal', {
        -alias    => { eat => 'drink' },
    };
}

ok(Dog->can('eat'));
ok(Dog->can('drink'));

my $d = Dog->new();
is($d->drink(), 'delicious');
is($d->eat(),   'delicious');

my $t = Tama->new;
is $t->drink(), 'delicious';
is $t->eat(),    'good!';

