#!perl

### MODULES


{
    package PlainMoose;
    use Moose;
    has foo => (is => 'rw');

    sub DEMOLISH { }
    __PACKAGE__->meta->make_immutable();
}
{
    package PlainMouse;
    use Mouse;
    has foo => (is => 'rw');

    sub DEMOLISH { }
    __PACKAGE__->meta->make_immutable();
}
{
    package ClassAccessorFast;
    use warnings;
    use strict;
    use base 'Class::Accessor::Fast';
    __PACKAGE__->mk_accessors(qw(foo));

    sub DESTROY { }
}

use Benchmark qw(cmpthese);

my $moose                = PlainMoose->new;
my $mouse                = PlainMouse->new;
my $caf                  = ClassAccessorFast->new;

print "\nCREATION AND DESTRUCTION\n";
cmpthese(-1, {
    Moose                       => sub { my $x = PlainMoose->new(foo => 23) },
    Mouse                       => sub { my $x = PlainMouse->new(foo => 23) },
    ClassAccessorFast           => sub { my $x = ClassAccessorFast->new({foo => 23}) },
}, 'noc');
