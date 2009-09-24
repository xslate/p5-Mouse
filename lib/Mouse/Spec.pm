package Mouse::Spec;

use strict;
use version;

our $VERSION = '0.33';

our $MouseVersion = $VERSION;
our $MooseVersion = '0.90';

sub MouseVersion{ $MouseVersion }
sub MooseVersion{ $MooseVersion }


1;
__END__
