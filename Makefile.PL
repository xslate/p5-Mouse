use strict;
use warnings;
use inc::Module::Install;

name     'Mouse';
all_from 'lib/Mouse.pm';

tests 't/*.t t/*/*.t';

# Scalar::Util < 1.14 has a bug.
# > Fixed looks_like_number(undef) to return false for perl >= 5.009002
requires 'Scalar::Util' => 1.14;

test_requires 'Test::More'      => 0.88;
test_requires 'Test::Exception' => 0.27;
# test_requires 'Test::Output'    => 0.16; # too many dependencies!

include 'Test::Exception'; # work around 0.27_0x (its use of diehook might be wrong)

recommends 'MRO::Compat' if $] < 5.010;

if ($Module::Install::AUTHOR) {
    local @INC = ('lib', @INC);
    require 'lib/Mouse/Spec.pm';
    my $require_version = Mouse::Spec->MooseVersion;

    if (eval{ require Moose; Moose->VERSION($require_version) }) {
        if (eval 'use Module::Install::AuthorTests; 1') {
            create_moose_compatibility_test();
            recursive_author_tests('xt');
        } else {
            print "you don't have a M::I::AuthorTests.\n";
        }
    } else {
        print "you don't have Moose $require_version. skipping moose compatibility test\n";
    }
    system("author/generate-mouse-tiny.pl");
}

WriteAll check_nmake => 0;

sub create_moose_compatibility_test {
    require File::Path;
    require File::Spec;
    require File::Basename;

    print "Creating compatibility tests in xt/compatibility/* ...\n";

    File::Path::rmtree(File::Spec->catfile('xt', 'compatibility'));

    # some test does not pass... currently skip it.
    my %SKIP_TEST = (
        '016-trigger.t'    => "trigger's argument is incompatble :(",
        '010-isa-or.t'     => "Mouse has a [BUG]",

        '052-undefined-type-in-union.t' => "Mouse accepts undefined type as a member of union types",
        '054-anon-leak.t'     => 'Moose has memory leaks',

        '600-tiny-tiny.t'     => "Moose doesn't support ::Tiny",
        '601-tiny-mouse.t'    => "Moose doesn't support ::Tiny",
        '602-mouse-tiny.t'    => "Moose doesn't support ::Tiny",

        '031_roles_applied_in_create.t' => 't/lib/* classes are not Moose classes/roles',
    );

    my @compat_tests;

    File::Find::find(
        {
            wanted => sub {
                return unless -f $_;

                return if /failing/; # skip tests in failing/ directories which  are Moose specific

                return if /100_with_moose/; # tests with Moose
                return if /deprecated/;

                my $basename = File::Basename::basename($_);
                return if $basename =~ /^\./;

                if(exists $SKIP_TEST{$basename}){
                    print "# skip $basename because: $SKIP_TEST{$basename}\n";
                    return;
                }

                my $dirname = File::Basename::dirname($_);

                my $tmpdir = File::Spec->catfile('xt', 'compatibility', $dirname);
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

    clean_files "@compat_tests";
}

