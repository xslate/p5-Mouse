use strict;
use warnings;
use Test::More;

plan skip_all => 'todo';

# See
#  t/020_attributes/011_more_attr_delegation.t
#  https://github.com/gfx/p5-Mouse/issues/86
#  https://github.com/gfx/p5-Mouse/pull/90
{
    package A;
    use Mouse;

    # if "handles" is a Regexp, "isa" is required. So this block dies
    eval { has attr => (is => "ro", handles => qr/./) };

    # but "attr" is registered somehow, so this emits
    # "You are overwriting a locally defined method (attr) with an accessor"
    # I think this implies Mouse may leak something...
    my @warn;
    {
        local $SIG{__WARN__} = sub { push @warn, @_ };
        has attr => (is => 'ro');
    }
    ::is @warn, 0;
}

done_testing;
