#!perl -w
use strict;
use warnings;

use Test::More tests => 25;

my @seen;
my @expected = ("before 4",
                  "before 3",
                    "around 4 before",
                      "around 3 before",
                        "before 2",
                          "before 1",
                            "around 2 before",
                              "around 1 before",
                                "orig",
                              "around 1 after",
                            "around 2 after",
                          "after 1",
                        "after 2",
                      "around 3 after",
                    "around 4 after",
                  "after 3",
                "after 4",
               );

my $child = Grandchild->new; $child->orig;

is_deeply(\@seen, \@expected, "multiple afters called in the right order");

BEGIN {
    package Parent;
    use Mouse;

    sub orig {
        push @seen, "orig";
    }
}

BEGIN {
    package Child;
    use Mouse;
    extends 'Parent';

    before orig => sub {
        push @seen, "before 1";
    };

    before orig => sub {
        push @seen, "before 2";
    };

    around orig => sub {
        my $orig = shift;
        push @seen, "around 1 before";
        $orig->();
        push @seen, "around 1 after";
    };

    around orig => sub {
        my $orig = shift;
        push @seen, "around 2 before";
        $orig->();
        push @seen, "around 2 after";
    };

    after orig => sub {
        push @seen, "after 1";
    };

    after orig => sub {
        push @seen, "after 2";
    };
}

BEGIN {
    package Grandchild;
    use Mouse;
    extends 'Child';

    before orig => sub {
        push @seen, "before 3";
    };

    before orig => sub {
        push @seen, "before 4";
    };

    around orig => sub {
        my $orig = shift;
        push @seen, "around 3 before";
        $orig->();
        push @seen, "around 3 after";
    };

    around orig => sub {
        my $orig = shift;
        push @seen, "around 4 before";
        $orig->();
        push @seen, "around 4 after";
    };

    after orig => sub {
        push @seen, "after 3";
    };

    after orig => sub {
        push @seen, "after 4";
    };
}

# from Class::Method::Modifers' t/020-multiple-inheritance.t

# inheritance tree looks like:
#
#    SuperL        SuperR
#      \             /
#      MiddleL  MiddleR
#         \       /
#          -Child-

# the Child and MiddleR modules use modifiers
# Child will modify a method in SuperL (sl_c)
# Child will modify a method in SuperR (sr_c)
# Child will modify a method in SuperR already modified by MiddleR (sr_m_c)
# SuperL and MiddleR will both have a method of the same name, doing different
#     things (called 'conflict' and 'cnf_mod')

# every method and modifier will just return <Class:Method:STUFF>

BEGIN
{
    {
        package SuperL;
        use Mouse;

        sub superl { "<SuperL:superl>" }
        sub conflict { "<SuperL:conflict>" }
        sub cnf_mod { "<SuperL:cnf_mod>" }
        sub sl_c { "<SuperL:sl_c>" }
    }

    {
        package SuperR;
        use Mouse;

        sub superr { "<SuperR:superr>" }
        sub sr_c { "<SuperR:sr_c>" }
        sub sr_m_c { "<SuperR:sr_m_c>" }
    }

    {
        package MiddleL;
        use Mouse;
        extends 'SuperL';

        sub middlel { "<MiddleL:middlel>" }
    }

    {
        package MiddleR;
        use Mouse;
        extends 'SuperR';

        sub middler { "<MiddleR:middler>" }
        sub conflict { "<MiddleR:conflict>" }
        sub cnf_mod { "<MiddleR:cnf_mod>" }
        around sr_m_c => sub {
            my $orig = shift;
            return "<MiddleR:sr_m_c:".$orig->(@_).">"
        };
    }

    {
        package Child;
        use Mouse;
        extends qw(MiddleL MiddleR);

        sub child { "<Child:child>" }
        around cnf_mod => sub { "<Child:cnf_mod:".shift->(@_).">" };
        around sl_c => sub { "<Child:sl_c:".shift->(@_).">" };
        around sr_c => sub { "<Child:sr_c:".shift->(@_).">" };
        around sr_m_c => sub {
            my $orig = shift;
            return "<Child:sr_m_c:".$orig->(@_).">"
        };
    }
}


my $SuperL = SuperL->new();
my $SuperR = SuperR->new();
my $MiddleL = MiddleL->new();
my $MiddleR = MiddleR->new();
my $Child = Child->new();

is($SuperL->superl, "<SuperL:superl>", "SuperL loaded correctly");
is($SuperR->superr, "<SuperR:superr>", "SuperR loaded correctly");
is($MiddleL->middlel, "<MiddleL:middlel>", "MiddleL loaded correctly");
is($MiddleR->middler, "<MiddleR:middler>", "MiddleR loaded correctly");
is($Child->child, "<Child:child>", "Child loaded correctly");

is($SuperL->sl_c, "<SuperL:sl_c>", "SuperL->sl_c on SuperL");
is($Child->sl_c, "<Child:sl_c:<SuperL:sl_c>>", "SuperL->sl_c wrapped by Child's around");

is($SuperR->sr_c, "<SuperR:sr_c>", "SuperR->sr_c on SuperR");
is($Child->sr_c, "<Child:sr_c:<SuperR:sr_c>>", "SuperR->sr_c wrapped by Child's around");

is($SuperR->sr_m_c, "<SuperR:sr_m_c>", "SuperR->sr_m_c on SuperR");
is($MiddleR->sr_m_c, "<MiddleR:sr_m_c:<SuperR:sr_m_c>>", "SuperR->sr_m_c wrapped by MiddleR's around");
is($Child->sr_m_c, "<Child:sr_m_c:<MiddleR:sr_m_c:<SuperR:sr_m_c>>>", "MiddleR->sr_m_c's wrapping wrapped by Child's around");

is($SuperL->conflict, "<SuperL:conflict>", "SuperL->conflict on SuperL");
is($MiddleR->conflict, "<MiddleR:conflict>", "MiddleR->conflict on MiddleR");
is($Child->conflict, "<SuperL:conflict>", "SuperL->conflict on Child");

is($SuperL->cnf_mod, "<SuperL:cnf_mod>", "SuperL->cnf_mod on SuperL");
is($MiddleR->cnf_mod, "<MiddleR:cnf_mod>", "MiddleR->cnf_mod on MiddleR");
is($Child->cnf_mod, "<Child:cnf_mod:<SuperL:cnf_mod>>", "SuperL->cnf_mod wrapped by Child's around");

# taken from Class::Method::Modifiers' t/051-undef-list-ctxt.t
my($orig_called, $after_called);
BEGIN
{
    package ParentX;
    use Mouse;

    sub orig
    {
        my $self = shift;
        $orig_called = 1;
        return;
    }

    package ChildX;
    use Mouse;
    extends 'ParentX';

    after 'orig' => sub
    {
        $after_called = 1;
    };
}

{
    ($after_called, $orig_called) = (0, 0);
    my $child = ChildX->new();
    my @results = $child->orig();

    ok($orig_called, "original method called");
    ok($after_called, "after-modifier called");
    is(@results, 0, "list context with after doesn't screw up 'return'");

    ($after_called, $orig_called) = (0, 0);
    my $result = $child->orig();

    ok($orig_called, "original method called");
    ok($after_called, "after-modifier called");
    is($result, undef, "scalar context with after doesn't screw up 'return'");
}
