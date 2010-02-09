#!perl
package Point;
use Mouse;

has 'x' => (isa => 'Int', is => 'rw', required => 1);
has 'y' => (isa => 'Int', is => 'rw', required => 1);

sub clear {
  my $self = shift;
  $self->x(0);
  $self->y(0);
}

package Point3D;
use Mouse;

extends 'Point';

has 'z' => (isa => 'Int', is => 'rw', required => 1);

after 'clear' => sub {
  my $self = shift;
  $self->z(0);
};

package main;

# hash or hashrefs are ok for the constructor
my $point1 = Point->new(x => 5, y => 7);
my $point2 = Point->new({x => 5, y => 7});

my $point3d = Point3D->new(x => 5, y => 42, z => -5);

print "point1: ", $point1->dump();
print "point2: ", $point2->dump();
print "point3: ", $point3d->dump();

print "point3d->clear()\n";
$point3d->clear();
print "point3: ", $point3d->dump();
