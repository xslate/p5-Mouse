#!/usr/bin/perl

use strict;
use warnings;

use Test::More tests => 8;
use Test::Exception;

# Some packages out in the wild cooperate with Mouse by using goto
# &Mouse::import. we want to make sure it still works.

{
    package MouseAlike1;

    use strict;
    use warnings;

    use Mouse ();

    sub import {
        goto &Mouse::import;
    }

    sub unimport {
        goto &Mouse::unimport;
    }
}

{
    package Foo;

    MouseAlike1->import();

    ::lives_ok( sub { has( 'size', is => 'bare' ) },
                'has was exported via MouseAlike1' );

    MouseAlike1->unimport();
}

ok( ! Foo->can('has'),
    'No has sub in Foo after MouseAlike1 is unimported' );
ok( Foo->can('meta'),
    'Foo has a meta method' );
isa_ok( Foo->meta(), 'Mouse::Meta::Class' );


{
    package MouseAlike2;

    use strict;
    use warnings;

    use Mouse ();

    my $import = \&Mouse::import;
    sub import {
        goto $import;
    }

    my $unimport = \&Mouse::unimport;
    sub unimport {
        goto $unimport;
    }
}

{
    package Bar;

    MouseAlike2->import();

    ::lives_ok( sub { has( 'size', is => 'bare' ) },
                'has was exported via MouseAlike2' );

    MouseAlike2->unimport();
}


ok( ! Bar->can('has'),
          'No has sub in Bar after MouseAlike2 is unimported' );
ok( Bar->can('meta'),
    'Bar has a meta method' );
isa_ok( Bar->meta(), 'Mouse::Meta::Class' );
