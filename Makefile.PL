use strict;
use warnings;
use inc::Module::Install;

# for co-developpers
use Module::Install::XSUtil 0.17;

system($^X, 'tool/generate-mouse-tiny.pl', 'lib/Mouse/Tiny.pm') == 0
    or warn "Cannot generate Mouse::Tiny: $!";

name     'Mouse';
all_from 'lib/Mouse.pm';

# Scalar::Util < 1.14 has a bug.
# > Fixed looks_like_number(undef) to return false for perl >= 5.009002
requires 'Scalar::Util' => 1.14;

test_requires 'Test::More'      => 0.88;
test_requires 'Test::Exception' => 0.27;
# test_requires 'Test::Output'    => 0.16; # too many dependencies!

include_deps 'Test::Exception'; # work around 0.27_0x (its use of diehook might be wrong)

recommends 'MRO::Compat' if $] < 5.010;

require 'lib/Mouse/Spec.pm'; # for the version

if(Mouse::Spec->MouseVersion =~ /_/){ # DEVEL RELEASE
    require Carp::Always; Carp::Always->import();
    include_deps 'Carp::Always';
}

my $use_xs;

for (@ARGV) {
    /^--pp$/ and $use_xs = 0;
    /^--xs$/ and $use_xs = 1;
}

if($] < 5.008_001){
    $use_xs = 0;
}

if(!defined $use_xs){
    $use_xs = cc_available();
}

if($use_xs){
    print "Mouse configured with XS.\n",
          "NOTE: You can try --pp option to configure Mouse with Pure Perl.\n";

    use_ppport(3.19);
    cc_warnings();
    cc_src_paths('xs-src');
}
else{
    print "Mouse configured with Pure Perl.\n";
}

if (author_context()) {
    my $require_version = Mouse::Spec->MooseVersion;

    if (eval { require Moose; Moose->VERSION($require_version) }) {
        if (eval { require Module::Install::AuthorTests }) {
            do 'tool/create-moose-compatibility-tests.pl';
            recursive_author_tests('xt');
        } else {
            print "you don't have a M::I::AuthorTests.\n";
        }
    } else {
        print "you don't have Moose $require_version. skipping moose compatibility test\n";
    }

    if($use_xs){
        # repeat testing
        # see also ExtUtils::MM_Any::test_via_harness()
        my $test_via_harness =  q{$(FULLPERLRUN) -MExtUtils::Command::MM -e}
                               .q{ "do 'tool/force-pp.pl'; test_harness($(TEST_VERBOSE), '$(INST_LIB)', '$(INST_ARCHLIB)')"}
                               .q{ $(TEST_FILES)} . "\n";

        postamble qq{test_dynamic :: test_pp\n\n}
                . qq{test_pp :: pure_all\n}
                . qq{\t} . $test_via_harness;
    }
}

tests 't/*.t t/*/*.t';

clean_files 'lib/Mouse/Tiny.pm $(O_FILES)';

WriteAll check_nmake => 0;
