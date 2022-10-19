#!perl
# https://github.com/xslate/p5-Mouse/issues/114

use strict;
use warnings;
use Test::More;

BEGIN {
    package Bar;
    use strict;
    use warnings;
    use Mouse;
    has [qw/
        p1   p2   p3   p4   p5   p6   p7   p8   p9   p10
        p11  p12  p13  p14  p15  p16  p17  p18  p19  p20
        p21  p22  p23  p24  p25  p26  p27  p28  p29  p30
        p31  p32  p33  p34  p35  p36  p37  p38  p39  p40
        p41  p42  p43  p44  p45  p46  p47  p48  p49  p50
        p51  p52  p53  p54  p55  p56  p57  p58  p59  p60
        p61  p62  p63  p64  p65  p66  p67  p68  p69  p70
        p71  p72  p73  p74  p75  p76  p77  p78  p79  p80
        p81  p82  p83  p84  p85  p86  p87  p88  p89  p90
        p91  p92  p93  p94  p95  p96  p97  p98  p99  p100
        p101 p102 p103 p104 p105 p106 p107 p108 p109 p110
        p111 p112 p113 p114 p115 p116 p117 p118 p119 p120
        p121 p122 p123 p124 p125 p126
    /] => (
        is => 'ro'
    );
    no Mouse;
    __PACKAGE__->meta->make_immutable;
}

is(scalar(@{[Bar->meta->get_all_attributes]}), 126, "get_all_attributes() returns a correct value");

done_testing;
