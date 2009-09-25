package Mouse::Meta::Method;
use strict;
use warnings;

use Mouse::Util qw(:meta);

use overload
    '&{}' => 'body',
    fallback => 1,
;

sub new{
    my($class, %args) = @_;

    return bless \%args, $class;
}

sub body        { $_[0]->{body}    }
sub name        { $_[0]->{name}    }
sub package_name{ $_[0]->{package} }


1;

__END__
