#!perl -w
use strict;
use FindBin qw($Bin);
use autodie;

my %dist = (
    'HTTP-Engine'  => q{git://github.com/http-engine/HTTP-Engine.git},
    'HTTP-Engine-Middleware'
                   => q{git://github.com/http-engine/HTTP-Engine-Middleware.git},

    'Ark'          => q{git://github.com/typester/ark-perl.git},
    'Object-Container'
                    => q{git://github.com/typester/object-container-perl.git},

    'MouseX-Types'  => q{git://github.com/yappo/p5-mousex-types.git},

    'Data-Localize' => q{git://github.com/lestrrat/Data-Localize.git},

    'AnyEvent-ReverseHTTP'
                    => q{git://github.com/miyagawa/AnyEvent-ReverseHTTP.git},

    'HTML-Shakan'   => q{git://github.com/tokuhirom/html-shakan.git},
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
    system("$^X Makefile.PL 2>&1 |tee ../$name.log");

    print "make\n";
    system("make 2>&1 >>../$name.log");

    print "make test\n";
    system("make test 2>&1 |tee -a ../$name.log")
}
