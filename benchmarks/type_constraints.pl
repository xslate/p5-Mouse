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
    use Mouse::Util::TypeConstraints;
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

    has with_tc_array_of_int => (
        is  => 'rw',
        isa => 'ArrayRef[Int]',
    );

    has with_tc_duck_type => (
        is  => 'rw',
        isa => duck_type([qw(simple)]),
    );
    __PACKAGE__->meta->make_immutable;
}
{
    package MooseOne;
    use Moose;
    use Moose::Util::TypeConstraints;
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
    has with_tc_array_of_int => (
        is  => 'rw',
        isa => 'ArrayRef[Int]',
    );
    has with_tc_duck_type => (
        is  => 'rw',
        isa => duck_type([qw(simple)]),
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

print "\nSETTING for attributes with type constraints 'ArrayRef[Int]' (except for C::XSAccessor)\n";

$foo = [10, 20];
cmpthese -1 => {
    'Mouse' => sub{
        $mi->with_tc_array_of_int($foo);
        $mi->with_tc_array_of_int($foo);
    },
    'Moose' => sub{
        $mx->with_tc_array_of_int($foo);
        $mx->with_tc_array_of_int($foo);
    },
    $cxsa_is_loaded ? (
    'C::XSAccessor' => sub{
        $cx->simple($foo);
        $cx->simple($foo);
    },
    ) : (),
};

print "\nSETTING for attributes with type constraints duck_type() (except for C::XSAccessor)\n";

$foo = MouseOne->new();
cmpthese -1 => {
    'Mouse' => sub{
        $mi->with_tc_duck_type($foo);
        $mi->with_tc_duck_type($foo);
    },
    'Moose' => sub{
        $mx->with_tc_duck_type($foo);
        $mx->with_tc_duck_type($foo);
    },
    $cxsa_is_loaded ? (
    'C::XSAccessor' => sub{
        $cx->simple($foo);
        $cx->simple($foo);
    },
    ) : (),
};
