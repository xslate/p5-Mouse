#!/usr/bin/env perl
use Test::More tests => 1;
use Test::Exception;

throws_ok {
    package Class;
    use Mouse;

    my $foo = '$foo';
    chop $$foo;
} qr/Can't use string \("\$foo"\) as a SCALAR ref while "strict refs" in use /,
  'using Mouse turns on strictures';

