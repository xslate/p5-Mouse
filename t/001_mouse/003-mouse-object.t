#!/usr/bin/env perl
use strict;
use warnings;
use Test::More tests => 1;

require Mouse;

can_ok('Mouse::Object' => 'new');
