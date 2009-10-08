package Mouse::Spec;
use strict;
use warnings;

our $VERSION = '0.37_04';

our $MouseVersion = $VERSION;
our $MooseVersion = '0.90';

sub MouseVersion{ $MouseVersion }
sub MooseVersion{ $MooseVersion }

1;
__END__
