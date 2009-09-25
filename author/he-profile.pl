#!perl -w
# Usage: perl author/profile.pl (no other options including -Mblib are reqired)

use strict;

my $script = 'bench/foo.pl';

my $branch = do{
	open my $in, '.git/HEAD' or die "Cannot open .git/HEAD: $!";
	my $s = scalar <$in>;
	chomp $s;
	$s =~ s{^ref: \s+ refs/heads/}{}xms;
	$s =~ s{/}{_}xmsg;
	$s;
};

print "Profiling $branch ...\n";

my @cmd = ($^X, '-Iblib/lib', '-Iblib/arch', '-d:NYTProf', '-e',
    'require HTTP::Engine; require HTTP::Engine::Interface::CGI');

print "> @cmd\n";
system(@cmd) == 0 or die "Cannot profile";
system(@cmd) == 0 or die "Cannot profile";
system(@cmd) == 0 or die "Cannot profile";

@cmd = ($^X, '-S', 'nytprofhtml', '--out', "nytprof-$branch");
print "> @cmd\n";
system(@cmd) == 0 or die "Cannot profile";
