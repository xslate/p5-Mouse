#!perl
use strict;
use warnings;
use Benchmark qw/cmpthese/;

use Class::MOP;
use Mouse();

print "Class::MOP $Class::MOP::VERSION\n";
print "Mouse      $Mouse::VERSION\n";

cmpthese -1 => {
    'Class::MOP::load_class' => sub{
        Class::MOP::load_class('Class::MOP::Class');
    },
    'Mouse::Util::load_class' => sub{
        Mouse::Util::load_class('Class::MOP::Class');
    },
};
