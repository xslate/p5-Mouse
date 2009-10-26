#!perl
use strict;
use warnings;
use Benchmark qw/cmpthese/;

{
    package Foo;
    sub new{ bless {}, shift }
}

eval q{
    package C::XSAOne;
    use Class::XSAccessor
        constructor => 'new',
        accessors   => { n => 'n' },
    ;
    1;
};

for my $klass (qw/Moose Mouse/) {
    eval qq{
        package ${klass}One;
        use $klass;

        has n => (
            is  => 'rw',
            isa => 'Foo',
        );
        no $klass;
        __PACKAGE__->meta->make_immutable;
    };
    die $@ if $@;
}

print "Class::MOP: $Class::MOP::VERSION\n";
print "Moose:      $Moose::VERSION\n";
print "Mouse:      $Mouse::VERSION\n";
print "---- new\n";

my $foo = Foo->new();

my @classes = qw(Moose Mouse);
if(C::XSAOne->can('new')){
    push @classes, 'C::XSA';
}

cmpthese(
    -1 => {
        map { my $x = $_; $_ => sub { $x->new(n => $foo) } }
        map { "${_}One" } @classes
    }
);

print "---- new,set\n";
cmpthese(
    -1 => {
        map { my $y = $_; $_ => sub { $y->new(n => $foo)->n($foo) } }
        map { "${_}One" } @classes
    }
);

print "---- set\n";
my %c = map { $_ => "${_}One"->new(n => $foo) } @classes;
cmpthese(
    -1 => {
        map { my $y = $_; $_ => sub { $c{$y}->n($foo) } } @classes
    }
);
