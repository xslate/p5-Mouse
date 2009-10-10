use strict;
use warnings;

use Test::More tests => 1;
use Test::Exception;

use Mouse::Meta::Class;

$SIG{__WARN__} = sub { die if shift =~ /recurs/ };

TODO:
{
#    local $TODO
#        = 'Loading Mouse::Meta::Class without loading Mouse.pm causes weird problems';

    my $meta;
    lives_ok {
        $meta = Mouse::Meta::Class->create_anon_class(
            superclasses => [ 'Mouse::Object', ],
        );
    }
    'Class is created successfully';
}
