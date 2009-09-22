use strict;
use warnings;
use inc::Module::Install;
use 5.008;

name     'Mouse';
all_from 'lib/Mouse.pm';

tests 't/*.t t/*/*.t';

# Scalar::Util < 1.14 has a bug.
# > Fixed looks_like_number(undef) to return false for perl >= 5.009002
requires 'Scalar::Util' => 1.14;

build_requires 'Test::Exception' => 0.21;
build_requires 'Test::More' => 0.80;

if ($Module::Install::AUTHOR) {
    if (eval "package foo; use Moose; 1;") {
        if (eval 'use Module::Install::AuthorTests; 1') {
            create_moose_compatibility_test();
            recursive_author_tests('xt');
        } else {
            print "you don't have a M::I::AuthorTests.\n";
        }
    } else {
        print "you don't have a moose. skipping moose compatibility test\n";
    }
    system("author/generate-mouse-tiny.pl");
}

auto_include;
WriteAll;

sub create_moose_compatibility_test {
    require File::Path;
    require File::Spec;
    require File::Basename;

    print "Creating compatibility tests in xt/compatibility/* ...\n";

    File::Path::rmtree(File::Spec->catfile('xt', 'compatibility'));

    # some test does not pass... currently skip it.
    my %SKIP_TEST = (
        '016-trigger.t'    => "trigger's argument is incompatble :(",
        '029-new.t'        => 'Class->new(undef) incompatible',
        '010-isa-or.t'     => 'Mouse has a [BUG]',
        '044-attribute-metaclass.t' => 'Moose::Meta::Attribute does not have a "create"',
        '047-attribute-metaclass-role.t' => 'Moose::Meta::Attribute does not have a "create"',
        '201-squirrel.t'      => 'skip Squirrel',
        '202-squirrel-role.t' => 'Squirrel is ...',
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

                return if /failing/; # skip tests in failing/ directories

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
                    $src =~ s/Mouse::is_class_loaded/Class::MOP::is_class_loaded/g;
                    $src =~ s/Mouse::load_class/Class::MOP::load_class/g;
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

