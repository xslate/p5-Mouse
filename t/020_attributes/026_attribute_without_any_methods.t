#!/usr/bin/perl
BEGIN{ $ENV{MOUSE_VERBOSE} = 1 }
use strict;
use warnings;

use Test::More tests => 2;

use Mouse ();
use Mouse::Meta::Class;

my $meta = Mouse::Meta::Class->create('Banana');

my $warn;
$SIG{__WARN__} = sub { $warn = "@_" };

$meta->add_attribute('foo');
like $warn, qr/Attribute \(foo\) of class Banana has no associated methods/,
  'correct error message';

$warn = '';
$meta->add_attribute('bar', is => 'bare');
is $warn, '', 'add attribute with no methods and is => "bare"';
