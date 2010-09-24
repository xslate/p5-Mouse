#!/usr/bin/perl

use strict;
use warnings;

use Test::More tests => 4;
use Test::Exception;



=pod

This test demonstrates that Mouse will respect
a metaclass previously set with the metaclass
pragma.

It also checks an error condition where that
metaclass must be a Mouse::Meta::Class subclass
in order to work.

=cut


{
    package Foo::Meta;
    use strict;
    use warnings;

    use base 'Mouse::Meta::Class';

    package Foo;
    use strict;
    use warnings;
    use metaclass 'Foo::Meta';
    ::use_ok('Mouse');
}

isa_ok(Foo->meta, 'Foo::Meta');

{
    package Bar::Meta;
    use strict;
    use warnings;

    use base 'Class::MOP::Class';

    package Bar;
    use strict;
    use warnings;
    use metaclass 'Bar::Meta';
    eval 'use Mouse;';
    ::ok($@, '... could not load moose without correct metaclass');
    ::like($@,
        qr/^Bar already has a metaclass, but it does not inherit Mouse::Meta::Class/,
        '... got the right error too');
}
