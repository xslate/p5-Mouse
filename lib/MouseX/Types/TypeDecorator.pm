package MouseX::Types::TypeDecorator;

use strict;
use warnings;

use Scalar::Util 'blessed';

use overload(
    '""' => sub { ${ $_[0] } },
    '|' => sub {
        
        ## It's kind of ugly that we need to know about Union Types, but this
        ## is needed for syntax compatibility.  Maybe someday we'll all just do
        ## Or[Str,Str,Int]
        
        my @tc = grep {blessed $_} @_;
        use Data::Dumper;
        my $ret;
        if (ref($_[0])) {
            $ret = ${ $_[0] };
        } else {
            $ret = $_[0];
        }
        $ret .= '|';
        if (ref($_[1])) {
            $ret .= ${ $_[1] };
        } else {
            $ret .= $_[1];
        }
        $ret;
    },
    fallback => 1,
    
);

sub new {
    my $type = $_[1];
    bless \$type, $_[0];
}

1;
