#!perl
use strict;
use Benchmark qw(:all);
use Config; printf "Perl/%vd in $Config{archname}\n\n", $^V;
use warnings;
no warnings 'once';

my $cxsa_is_loaded = eval q{
    package CXSA;
    use Class::XSAccessor
        constructor => 'new',
        accessors   => {
            simple => 'simple',
        },
    ;
    1;
};

{
    package Foo;
    sub new { bless {}, shift }
}

{
    package MouseOne;
    use Mouse;
    has simple => (
        is => 'rw',
    );
    has with_lazy => (
        is      => 'rw',
        lazy    => 1,
        default => 42,
    );
    has with_tc => (
        is  => 'rw',
        isa => 'Int',
    );

    has with_tc_class_type => (
        is  => 'rw',
        isa => 'Foo',
    );

    __PACKAGE__->meta->make_immutable;
}
{
    package MooseOne;
    use Moose;
    has simple => (
        is => 'rw',
    );
    has with_lazy => (
        is      => 'rw',
        lazy    => 1,
        default => 42,
    );
    has with_tc => (
        is  => 'rw',
        isa => 'Int',
    );
    has with_tc_class_type => (
        is  => 'rw',
        isa => 'Foo',
    );

    __PACKAGE__->meta->make_immutable;
}

use B qw(svref_2object);

print "Moose/$Moose::VERSION (Class::MOP/$Class::MOP::VERSION)\n";
print "Mouse/$Mouse::VERSION\n";
print "Class::XSAccessor/$Class::XSAccessor::VERSION\n" if $cxsa_is_loaded;

my $mi = MouseOne->new();
my $mx = MooseOne->new();
my $cx;
$cx = CXSA->new       if $cxsa_is_loaded;


print "\nGETTING for simple attributes\n";
cmpthese -1 => {
    'Mouse' => sub{
        my $x;
        $x = $mi->simple();
        $x = $mi->simple();
    },
    'Moose' => sub{
        my $x;
        $x = $mx->simple();
        $x = $mx->simple();
    },
    $cxsa_is_loaded ? (
    'C::XSAccessor' => sub{
        my $x;
        $x = $cx->simple();
        $x = $cx->simple();
    },
    ) : (),
};

print "\nSETTING for simple attributes\n";
cmpthese -1 => {
    'Mouse' => sub{
        $mi->simple(10);
        $mi->simple(10);
    },
    'Moose' => sub{
        $mx->simple(10);
        $mx->simple(10);
    },
    $cxsa_is_loaded ? (
    'C::XSAccessor' => sub{
        $cx->simple(10);
        $cx->simple(10);
    },
    ) : (),

};

print "\nGETTING for lazy attributes (except for C::XSAccessor)\n";
cmpthese -1 => {
    'Mouse' => sub{
        my $x;
        $x = $mi->with_lazy();
        $x = $mi->with_lazy();
    },
    'Moose' => sub{
        my $x;
        $x = $mx->with_lazy();
        $x = $mx->with_lazy();
    },
    $cxsa_is_loaded ? (
    'C::XSAccessor' => sub{
        my $x;
        $x = $cx->simple();
        $x = $cx->simple();
    },
    ) : (),
};

print "\nSETTING for attributes with type constraints 'Int' (except for C::XSAccessor)\n";
cmpthese -1 => {
    'Mouse' => sub{
        $mi->with_tc(10);
        $mi->with_tc(10);
    },
    'Moose' => sub{
        $mx->with_tc(10);
        $mx->with_tc(10);
    },
    $cxsa_is_loaded ? (
    'C::XSAccessor' => sub{
        $cx->simple(10);
        $cx->simple(10);
    },
    ) : (),
};

print "\nSETTING for attributes with type constraints 'Foo' (except for C::XSAccessor)\n";
my $foo = Foo->new;
cmpthese -1 => {
    'Mouse' => sub{
        $mi->with_tc_class_type($foo);
        $mi->with_tc_class_type($foo);
    },
    'Moose' => sub{
        $mx->with_tc_class_type($foo);
        $mx->with_tc_class_type($foo);
    },
    $cxsa_is_loaded ? (
    'C::XSAccessor' => sub{
        $cx->simple($foo);
        $cx->simple($foo);
    },
    ) : (),
};
