#!perl

### MODULES


{
    package PlainMoose;
    use Moose;
    has foo => (is => 'rw');
    has bar => (is => 'rw');
    __PACKAGE__->meta->make_immutable();
}
{
    package PlainMooseSC;
    use Moose;
    use MooseX::StrictConstructor;
    has foo => (is => 'rw');
    has bar => (is => 'rw');
    __PACKAGE__->meta->make_immutable();
}
{
    package PlainMouse;
    use Mouse;
    has foo => (is => 'rw');
    has bar => (is => 'rw');
    __PACKAGE__->meta->make_immutable();
}
{
    package PlainMouseSC;
    use Mouse;
    has foo => (is => 'rw');
    has bar => (is => 'rw');
    __PACKAGE__->meta->make_immutable(strict_constructor => 1);
}
{
    package CAF;
    use warnings;
    use strict;
    use base 'Class::Accessor::Fast';
    __PACKAGE__->mk_accessors(qw(foo bar));
}

use Benchmark qw(cmpthese);

print "\nCREATION AND DESTRUCTION\n";
cmpthese(-1, {
    Moose               => sub { my $x = PlainMoose->new(foo => 23, bar => 42) },
    Mouse               => sub { my $x = PlainMouse->new(foo => 23, bar => 42) },
    MooseSC             => sub { my $x = PlainMooseSC->new(foo => 23, bar => 42) },
    MouseSC             => sub { my $x = PlainMouseSC->new(foo => 23, bar => 42) },
    ClassAccessorFast   => sub { my $x = CAF->new({foo => 23, bar => 42}) },
}, 'noc');
