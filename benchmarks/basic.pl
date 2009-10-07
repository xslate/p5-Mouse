#!perl
use strict;
use warnings;
use Benchmark qw/cmpthese/;

for my $klass (qw/Moose Mouse/) {
    eval qq{
        package ${klass}One;
        use $klass;
        has n => (
            is     => 'rw',
            isa    => 'Int',
        );
        has m => (
            is      => 'rw',
            isa     => 'Int',
            default => 42,
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
cmpthese(
    -1 => {
        map { my $x = $_; $_ => sub { $x->new(n => 3) } }
        map { "${_}One" }
        qw/Moose Mouse/
    }
);

print "---- new,set\n";
cmpthese(
    -1 => {
        map { my $y = $_; $_ => sub { $y->new(n => 3)->n(5) } }
        map { "${_}One" }
        qw/Moose Mouse/
    }
);

print "---- set\n";
my %c = map { $_ => "${_}One"->new(n => 3) } qw/Moose Mouse/;
cmpthese(
    -1 => {
        map { my $y = $_; $_ => sub { $c{$y}->n(5) } }
        qw/Moose Mouse/
    }
);

print "---- get\n";
cmpthese(
    -1 => {
        map { my $y = $_; $_ => sub { $c{$y}->n() } }
        qw/Moose Mouse/
    }
);

