use strict;
use warnings;
use Benchmark qw/cmpthese/;
use String::TT qw/tt/;

for my $klass (qw/Moose Mouse/) {
    eval tt(q{
        package [% klass %]One;
        use [% klass %];
        has n => (
            is => 'rw',
            isa => 'Int',
        );
        no [% klass %];
        __PACKAGE__->meta->make_immutable;
    });
    die $@ if $@;
}

print "Class::MOP: $Class::MOP::VERSION\n";
print "Moose: $Moose::VERSION\n";
print "Mouse: $Mouse::VERSION\n";
print "---- new\n";
cmpthese(
    100000 => {
        map { my $x = $_; $_ => sub { $x->new(n => 3) } }
        map { "${_}One" }
        qw/Moose Mouse/
    }
);

print "---- new,set\n";
cmpthese(
    100000 => {
        map { my $y = $_; $_ => sub { $y->new(n => 3)->n(5) } }
        map { "${_}One" }
        qw/Moose Mouse/
    }
);
