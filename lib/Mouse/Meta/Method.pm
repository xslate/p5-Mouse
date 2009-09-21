package Mouse::Meta::Method;
use strict;
use warnings;

use overload
    '&{}' => 'body',
    fallback => 1,
;

sub new{
    my($class, %args) = @_;

    return bless \%args, $class;
}

sub body   { $_[0]->{body} }
sub name   { $_[0]->{name} }
sub package{ $_[0]->{name} }


1;

__END__
