#!perl -w

use strict;

use Test::More tests => 1;

use Mouse::PurePerl;
use Mouse;

ok !Mouse::Util::MOUSE_XS, 'load Mouse::PurePerl';

