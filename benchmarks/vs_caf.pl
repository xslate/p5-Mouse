#!perl

### MODULES


{
    package PlainMoose;
    use Moose;
    has foo => (is => 'rw');
    __PACKAGE__->meta->make_immutable();
}
{
    package PlainMouse;
    use Mouse;
    has foo => (is => 'rw');
    __PACKAGE__->meta->make_immutable();
}
{
    package ClassAccessorFast;
    use warnings;
    use strict;
    use base 'Class::Accessor::Fast';
    __PACKAGE__->mk_accessors(qw(foo));
}

use Benchmark qw(cmpthese);

my $moose                = PlainMoose->new;
my $mouse                = PlainMouse->new;
my $caf                  = ClassAccessorFast->new;


print "\nSETTING\n";
cmpthese(-1, {
    Moose                       => sub { $moose->foo(23) },
    Mouse                       => sub { $mouse->foo(23) },
    ClassAccessorFast           => sub { $caf->foo(23) },
}, 'noc');

print "\nGETTING\n";
cmpthese(-1, {
    Moose                       => sub { $moose->foo },
    Mouse                       => sub { $mouse->foo },
    ClassAccessorFast           => sub { $caf->foo },
}, 'noc');

print "\nCREATION AND DESTRUCTION\n";
cmpthese(-1, {
    Moose                       => sub { my $x = PlainMoose->new(foo => 23) },
    Mouse                       => sub { my $x = PlainMouse->new(foo => 23) },
    ClassAccessorFast           => sub { my $x = ClassAccessorFast->new({foo => 23}) },
}, 'noc');
