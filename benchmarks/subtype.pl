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

        has n => (
            is  => 'rw',
            isa => 'NaturalNumber',
        );
        no $klass;
        __PACKAGE__->meta->make_immutable;
    };
    die $@ if $@;
}

#use Data::Dumper;
#$Data::Dumper::Deparse = 1;
#$Data::Dumper::Indent  = 1;
#print Mouse::Util::TypeConstraints::find_type_constraint('NaturalNumber')->dump(3);
#print Moose::Util::TypeConstraints::find_type_constraint('NaturalNumber')->dump(3);

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
