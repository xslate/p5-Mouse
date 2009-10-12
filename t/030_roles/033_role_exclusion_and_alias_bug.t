#!/usr/bin/perl

use strict;
use warnings;

use Test::More tests => 17;
use lib 't/lib';
use Test::Mouse;

{
    package My::Role;
    use Mouse::Role;

    sub foo { "FOO" }
    sub bar { "BAR" }
}

{
    package My::Class;
    use Mouse;

    with 'My::Role' => {
        -alias    => { foo => 'baz', bar => 'gorch' },
        -excludes => ['foo', 'bar'],
    };
}

{
    my $x = My::Class->new;
    isa_ok($x, 'My::Class');
    does_ok($x, 'My::Role');

    can_ok($x, $_) for qw[baz gorch];

    ok(!$x->can($_), '... cant call method ' . $_) for qw[foo bar];

    is($x->baz, 'FOO', '... got the right value');
    is($x->gorch, 'BAR', '... got the right value');
}

{
    package My::Role::Again;
    use Mouse::Role;

    with 'My::Role' => {
        -alias    => { foo => 'baz', bar => 'gorch' },
        -excludes => ['foo', 'bar'],
    };

    package My::Class::Again;
    use Mouse;

    with 'My::Role::Again';
}

{
    my $x = My::Class::Again->new;
    isa_ok($x, 'My::Class::Again');
    does_ok($x, 'My::Role::Again');
    does_ok($x, 'My::Role');

    can_ok($x, $_) for qw[baz gorch];

    ok(!$x->can($_), '... cant call method ' . $_) for qw[foo bar];

    is($x->baz, 'FOO', '... got the right value');
    is($x->gorch, 'BAR', '... got the right value');
}


