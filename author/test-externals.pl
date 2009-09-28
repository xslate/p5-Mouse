#!perl -w
use strict;
use FindBin qw($Bin);
use autodie;

my %dist = (
    'HTTP-Engine' => q{git://github.com/http-engine/HTTP-Engine.git},
    'Ark'         => q{git://github.com/typester/ark-perl.git},

#    'Any-Moose'   => q{git://github.com/sartak/any-moose.git}, # has no Makefile.PL :(
);

my $distdir = 'externals';

chdir $Bin;
mkdir $distdir if not -e $distdir;

$ENV{ANY_MOOSE} = 'Mouse';

while(my($name, $repo) = each %dist){
    chdir "$Bin/$distdir";

    print "Go $name ($repo)\n";

    if(!(-e "$name")){
        system "git clone $repo $name";
        chdir $name;
    }
    else{
        chdir $name;
        system "git pull";
    }

    print "$^X Makefile.PL\n";
    system("$^X Makefile.PL");

    print "make test\n";
    system "make test";
}
