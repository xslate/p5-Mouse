#!/usr/bin/perl

use Test::More;

BEGIN {
    plan skip_all
           => 'perl 5.10 required to test Mouse/strict.pm/use 5.10 interaction'
             unless "$]" >= 5.010;
}

# without explicit 'strict'
{
    package Foo;
    use Mouse;
    use 5.010;

    eval 'sub bar { $x = 1 ; return $x }';
    ::ok($@, '... got an error because strict is on');
    ::like($@, qr/Global symbol \"\$x\" requires explicit package name/, '... got the right error');

}

# with explicit 'strict'
{
  package Foo;
  use Mouse;
  use 5.010;
  use strict;

  eval 'sub bar { $x = 1 ; return $x }';
  ::ok($@, '... got an error because strict is on');
  ::like($@, qr/Global symbol \"\$x\" requires explicit package name/, '... got the right error');

}

done_testing();
