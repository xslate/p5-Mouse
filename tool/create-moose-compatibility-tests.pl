#!perl
use strict;
use warnings;

use File::Path ();
use File::Spec ();
use File::Basename ();
use File::Find ();

print "Creating compatibility tests in xt/compat/* ...\n";

File::Path::rmtree(File::Spec->catfile('xt', 'compat'));

# some test does not pass... currently skip it.
my %SKIP_TEST = (
    '810-isa-or.t'     => "Mouse has a bug",

    '052-undefined-type-in-union.t' => "Mouse accepts undefined type as a member of union types",
    '054-anon-leak.t'     => 'Moose has memory leaks',

    '059-weak-with-default.t' => 'Moose has a bug',

    '600-tiny-tiny.t'     => "Moose doesn't support ::Tiny",
    '601-tiny-mouse.t'    => "Moose doesn't support ::Tiny",
    '602-mouse-tiny.t'    => "Moose doesn't support ::Tiny",
    '603-mouse-pureperl.t'=> "Moose doesn't have ::PurePerl",

    '031_roles_applied_in_create.t' => 't/lib/*.pm are not for Moose',
    '013_metaclass_traits.t'        => 't/lib/*.pm are not for Moose',
);

my @compat_tests;

File::Find::find(
    {
        wanted => sub {
            return unless -f $_;

            return if /failing/; # skip tests in failing/ directories which  are Moose specific

            return if /with_moose/; # tests with Moose
            return if /100_bugs/;   # some tests require Mouse specific files
            return if /deprecated/;

            my $basename = File::Basename::basename($_);
            return if $basename =~ /^\./;

            if(exists $SKIP_TEST{$basename}){
                print "# skip $basename because: $SKIP_TEST{$basename}\n";
                return;
            }

            my $dirname = File::Basename::dirname($_);

            my $tmpdir = File::Spec->catfile('xt', 'compat', $dirname);
            File::Path::mkpath($tmpdir);

            my $tmpfile = File::Spec->catfile($tmpdir, $basename);
            open my $wfh, '>', $tmpfile or die $!;
            print $wfh do {
                my $src = do {
                    open my $rfh, '<', $_ or die $!;
                    my $s = do { local $/; <$rfh> };
                    close $rfh;
                    $s;
                };
                $src =~ s/Mouse::(?:Util::)?is_class_loaded/Class::MOP::is_class_loaded/g;
                $src =~ s/Mouse::(?:Util::)?load_class/Class::MOP::load_class/g;
                $src =~ s/Mouse::Util::class_of/Class::MOP::class_of/g;
                $src =~ s/Mouse/Moose/g;
                $src;
            };
            close $wfh;
            push @compat_tests, $tmpfile;
        },
        no_chdir => 1
    },
    't',
);
print "Compatibility tests created.\n";

# clean_files("@compat_tests"); # defined in main


