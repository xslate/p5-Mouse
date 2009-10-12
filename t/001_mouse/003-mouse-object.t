#!/usr/bin/env perl
use strict;
use warnings;
use Test::More tests => 2;

require Mouse;
ok($INC{"Mouse/Object.pm"}, "loading Mouse loads Mouse::Object");
can_ok('Mouse::Object' => 'new');

