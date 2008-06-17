#!/usr/bin/env perl
use strict;
use warnings;
use Test::More tests => 1;
use Test::Exception;

lives_ok {
    package Role;
    use Mouse::Role;

    no Mouse::Role;
};

