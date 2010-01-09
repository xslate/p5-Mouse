#!perl
use strict;
use warnings;
use Benchmark qw/cmpthese/;


for my $klass (qw/Moose Mouse/) {
    eval qq{
        package ${klass}One;
        use $klass;
        use ${klass}::Util::TypeConstraints;

        subtype 'NaturalNumber', as 'Int', where { \$_ > 0 };

        coerce 'NaturalNumber',
            from 'Str', via { 42 },
        ;

        has n => (
            is     => 'rw',
            isa    => 'NaturalNumber',
            coerce => 1,
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
        map { my $x = $_; $_ => sub { $x->new(n => 'foo') } }
        map { "${_}One" }
        qw/Moose Mouse/
    }
);

print "---- new,set\n";
cmpthese(
    -1 => {
        map { my $y = $_; $_ => sub { $y->new(n => 'foo')->n('bar') } }
        map { "${_}One" }
        qw/Moose Mouse/
    }
);

print "---- set\n";
my %c = map { $_ => "${_}One"->new(n => 'foo') } qw/Moose Mouse/;
cmpthese(
    -1 => {
        map { my $y = $_; $_ => sub { $c{$y}->n('bar') } }
        qw/Moose Mouse/
    }
);
