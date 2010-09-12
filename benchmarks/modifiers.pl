#!perl -w
use strict;
use Benchmark qw(:all);

use Config;

use Moose ();
use Mouse ();
use Class::Method::Modifiers ();

printf "Perl %vd on $Config{archname}\n", $^V;
my @mods = qw(Moose Mouse Class::Method::Modifiers);

foreach my $class(@mods){
    print "$class ", $class->VERSION, "\n";
}
print "\n";

{
    package Base;
    sub f{ 42 }
    sub g{ 42 }
    sub h{ 42 }
}

my $i = 0;
sub around{
    my $next = shift;
    $i++;
    goto &{$next};
}
{
    package CMM;
    use parent -norequire => qw(Base);
    use Class::Method::Modifiers;

    before f => sub{ $i++ };
    around g => \&main::around;
    after  h => sub{ $i++ };
}
{
    package MooseClass;
    use parent -norequire => qw(Base);
    use Moose;

    before f => sub{ $i++ };
    around g => \&main::around;
    after  h => sub{ $i++ };
}
{
    package MouseClass;
    use parent -norequire => qw(Base);
    use Mouse;

    before f => sub{ $i++ };
    around g => \&main::around;
    after  h => sub{ $i++ };
}

print "Calling methods with before modifiers:\n";
cmpthese -1 => {
    CMM => sub{
        my $old = $i;
        CMM->f();
        $i == ($old+1) or die $i;
    },
    Moose => sub{
        my $old = $i;
        MooseClass->f();
        $i == ($old+1) or die $i;
    },
    Mouse => sub{
        my $old = $i;
        MouseClass->f();
        $i == ($old+1) or die $i;
    },
};

print "\n", "Calling methods with around modifiers:\n";
cmpthese -1 => {
    CMM => sub{
        my $old = $i;
        CMM->g();
        $i == ($old+1) or die $i;
    },
    Moose => sub{
        my $old = $i;
        MooseClass->g();
        $i == ($old+1) or die $i;
    },
    Mouse => sub{
        my $old = $i;
        MouseClass->g();
        $i == ($old+1) or die $i;
    },
};

print "\n", "Calling methods with after modifiers:\n";
cmpthese -1 => {
    CMM => sub{
        my $old = $i;
        CMM->h();
        $i == ($old+1) or die $i;
    },
    Moose => sub{
        my $old = $i;
        MooseClass->h();
        $i == ($old+1) or die $i;
    },
    Mouse => sub{
        my $old = $i;
        MouseClass->h();
        $i == ($old+1) or die $i;
    },
};
