#!/usr/bin/perl

use strict;
use warnings;

use lib 't/lib', 'lib';

use Test::More tests => 2;



use_ok('MyMouseA');
use_ok('MyMouseB');