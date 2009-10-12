package MyMouseA;

use Mouse;

has 'b' => (is => 'rw', isa => 'MyMouseB');

1;