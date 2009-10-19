use strict;
use warnings;
use Test::More;
use FindBin;
use File::Spec;
use lib File::Spec->catfile($FindBin::Bin, 'lib');

plan skip_all => 'This test requires Pod::Coverage::Moose' unless eval "use Pod::Coverage::Moose; 1";
plan tests => 1;

# support Pod::Coverage::Moose
#   https://rt.cpan.org/Ticket/Display.html?id=47744

TODO: {
    todo_skip 'not implemented yet', 1;
    my $cov = Pod::Coverage::Moose->new(package => 'Foo');
    is $cov->coverage, 0.5;
};
