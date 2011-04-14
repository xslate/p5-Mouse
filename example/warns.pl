#!perl
package Point;
use Mouse;
use MouseX::StrictConstructor;

# extra 'unknown_attr' is supplied (WARN)
has 'x' => (isa => 'Int', is => 'rw', required => 1, unknown_attr => 1);

# mandatory 'is' is not supplied (WARN)
has 'y' => (isa => 'Int', required => 1);

sub clear {
  my $self = shift;
  $self->x(0);
  $self->y(0);
}

__PACKAGE__->meta->make_immutable();

package main;

# extra 'z' is supplied (FATAL)
my $point1 = Point->new(x => 5, y => 7, z => 9);
