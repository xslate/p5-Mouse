#!perl -w
# Usage: perl author/profile.pl (no other options including -Mblib are reqired)

use strict;

my $script = 'author/use-he.pl';

my $branch = do{
    if(open my $in, '.git/HEAD'){
        my $s = scalar <$in>;
        chomp $s;
        $s =~ s{^ref: \s+ refs/heads/}{}xms;
        $s =~ s{/}{_}xmsg;
        $s;
    }
    else{
        require 'lib/Mouse/Spec.pm';
        Mouse::Spec->VERSION;
    }
};

print "Profiling $branch ...\n";

my @cmd = ($^X, '-Iblib/lib', '-Iblib/arch', '-d:NYTProf', $script);

print "> @cmd\n";
system(@cmd) == 0 or die "Cannot profile (\$?=$?)";
system(@cmd) == 0 or die "Cannot profile (\$?=$?)";
system(@cmd) == 0 or die "Cannot profile (\$?=$?)";

@cmd = ($^X, '-S', 'nytprofhtml', '--out', "nytprof-$branch");
print "> @cmd\n";
system(@cmd) == 0 or die "Cannot profile (\$?=$?)";
