package Bar;
use Mouse;

foreach my $i ( 0 .. 23 ) {
    has "attr_$i" => (
        is  => 'ro',
        isa => 'Str',
    );
}

1;

