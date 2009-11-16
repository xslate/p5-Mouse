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

my (@moose, @moose_immut, @mouse, @mouse_immut, @caf_stall);
print "\nCREATION\n";
cmpthese(1_000_000, {
    Moose                       => sub { push @moose, PlainMoose->new(foo => 23) },
    Mouse                       => sub { push @mouse, PlainMouse->new(foo => 23) },
    ClassAccessorFast           => sub { push @caf_stall, ClassAccessorFast->new({foo => 23}) },
}, 'noc');

my ( $moose_idx, $mouse_idx, $caf_idx ) = ( 0, 0, 0, 0 );
print "\nDESTRUCTION\n";
cmpthese(1_000_000, {
    Moose => sub {
        $moose[$moose_idx] = undef;
        $moose_idx++;
    },
    Mouse => sub {
        $mouse[$mouse_idx] = undef;
        $mouse_idx++;
    },
    ClassAccessorFast   => sub {
        $caf_stall[$caf_idx] = undef;
        $caf_idx++;
    },
}, 'noc');


