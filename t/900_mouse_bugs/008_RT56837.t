#!perl
# This test is contributed by Sanko Robinson.
# https://rt.cpan.org/Public/Bug/Display.html?id=56837
# "Role application to instance with init_arg'd attributes"
use strict;
use Test::More tests => 2;

{
    package Admin;
    use Mouse::Role;
    sub shutdown {1}
}
{
    package User;
    use Mouse;
    has 'name' =>
        (isa => 'Str', is => 'ro', init_arg => 'Name', required => 1);
}

package main;
my $tim = User->new(Name => 'Tim');

Admin->meta->apply($tim);

ok($tim->can('shutdown'),
    'The role was successfully composed at the object level');
is($tim->name, 'Tim',
    '... attribute with init_arg was re-initialized correctly');
