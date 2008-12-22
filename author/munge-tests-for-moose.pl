#!/usr/bin/env perl -pl
use strict;
use warnings;

BEGIN {
    @ARGV = glob('t/*.t t/*/*.t') if !@ARGV;
    $^I = '';
}

next if $ARGV =~ /squirrel/i; # Squirrel tests are for both Moose and Mouse

s/Mouse(?!::Tiny)/Moose/g;

s/Moose::(load_class|is_class_loaded)/Class::MOP::$1/g;

