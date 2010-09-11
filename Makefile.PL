# for developpers:
BEGIN{
    if(grep{ $_ eq '--author' } @ARGV){
        print "$^X -S cpanm < author/requires.cpanm\n";
        system "$^X -S cpanm < author/requires.cpanm";
    }
}

use strict;
use warnings;
use inc::Module::Install 1.00;

# for co-developpers
use Module::Install::XSUtil 0.30;
use Module::Install::AuthorTests;

system($^X, 'tool/generate-mouse-tiny.pl', 'lib/Mouse/Tiny.pm') == 0
    or warn "Cannot generate Mouse::Tiny: $!";

name     'Mouse';
all_from 'lib/Mouse.pm';

# Scalar::Util < 1.14 has a bug.
# > Fixed looks_like_number(undef) to return false for perl >= 5.009002
requires 'Scalar::Util' => 1.14;

test_requires 'Test::More'      => 0.88;
test_requires 'Test::Exception' => 0.29;

my %suggests = (
    'Any::Moose'                     => 0.10,

    'MouseX::AttributeHelpers'       => 0.06,
);
while(my($mod, $least) = each %suggests){
    my $status = system $^X, '-e', <<"CHECK";
if(eval q{ use $mod (); 1 }) {
    if(eval q{ use $mod $least (); 1 }) {
        exit 0; # installd, and new enough
    }
    else {
        exit 1; # installed, but too old
    }
}
CHECK

    if($status != 0){
        my $ver = `$^X -e "use $mod (); print $mod->VERSION"`;
        warn("\n",
            "WARNING: $mod is installed, but its version ($ver) is too old (< $least).\n",
            "         Please update $mod after installation of Mouse.\n",
            "\n"
        );
    }
}

# cc_want deals with the '--pp' and '--xs' options
my $use_xs = ($] >= 5.008_001 && want_xs());

if($use_xs){
    print "Mouse configured with XS.\n",
          "NOTE: You can try --pp option to configure Mouse with Pure Perl.\n";

    cc_warnings();
    use_ppport(3.19);
    use_xshelper();
    cc_src_paths('xs-src');
}
else{
    print "Mouse configured with Pure Perl.\n";
}


tests 't/*.t t/*/*.t';
author_tests 'xt';

repository 'git://git.moose.perl.org/Mouse.git';

if ($Module::Install::AUTHOR) {
    require 'lib/Mouse/Spec.pm'; # for the version
    my $require_version = Mouse::Spec->MooseVersion;

    if (eval { require Moose; Moose->VERSION($require_version) }) {
        print "You have Moose ", Moose->VERSION, ".\n";
        if (eval { require Module::Install::AuthorTests }) {
            do 'tool/create-moose-compatibility-tests.pl';
            # repeat testing
            # see also ExtUtils::MM_Any::test_via_harness()
            my $t_moose =  q{$(FULLPERLRUN) -MExtUtils::Command::MM -e}
                          .q{ "test_harness($(TEST_VERBOSE), '$(INST_LIB)', '$(INST_ARCHLIB)')"}
                          .q{ xt/compatibility/t/*/*.t } . "\n";

            postamble qq{test_dynamic :: test_moose\n\n}
                    . qq{test_moose :: pure_all\n}
                    . qq{\t} . $t_moose;
        } else {
            print "You don't have a M::I::AuthorTests.\n";
        }
    } else {
        print "You don't have Moose $require_version. skipping moose compatibility test\n";
    }

    if($use_xs){
        # repeat testing
        # see also ExtUtils::MM_Any::test_via_harness()
        my $t_pp =  q{$(FULLPERLRUN) -MExtUtils::Command::MM -e}
                   .q{ "do 'tool/force-pp.pl'; test_harness($(TEST_VERBOSE), '$(INST_LIB)', '$(INST_ARCHLIB)')"}
                   .q{ $(TEST_FILES)} . "\n";

        postamble qq{test_dynamic :: test_pp\n\n}
                . qq{test_pp :: pure_all\n}
                . qq{\t} . $t_pp;
    }
}

clean_files q{
    lib/Mouse/Tiny.pm $(O_FILES) test-mydeps-*.log
    *.out
    cover_db xs-src/*.gc{v,no,da}
};

WriteAll check_nmake => 0;
