# benchmark
use strict;
use warnings;
use Benchmark ':all';

{
    package Bench::CAF;
    use base 'Class::Accessor::Fast';
    __PACKAGE__->mk_accessors(qw/a/);
}

{
    package Bench::Mouse;
    use Mouse;
    has 'a' => ( is => 'rw' );
    no Mouse;
    __PACKAGE__->meta->make_immutable;
}

my $c = Bench::CAF->new;
my $m = Bench::Mouse->new;

print "-- new\n";
cmpthese(
    -1, {
        mouse => sub {
            Bench::Mouse->new()
        },
        caf => sub {
            Bench::CAF->new()
        },
    },
);

print "-- setter\n";
cmpthese(
    -1, {
        mouse => sub {
            $m->a(1);
        },
        caf => sub {
            $c->a(1)
        },
    },
);

print "-- getter\n";
cmpthese(
    -1, {
        mouse => sub {
            $m->a;
        },
        caf => sub {
            $c->a
        },
    },
);

