#!perl
use strict;
use warnings;
use Benchmark qw/cmpthese/;

use Class::MOP;
use Mouse();

print "Class::MOP $Class::MOP::VERSION\n";
print "Mouse      $Mouse::VERSION\n";

cmpthese -1 => {
    'Class::MOP' => sub{
        Class::MOP::load_class('Class::MOP::Class');
    },
    'Mouse' => sub{
        Mouse::Util::load_class('Class::MOP::Class');
    },
};
