BEGIN{ $INC{'Module/Install/ExtraTests.pm'} = __FILE__ } # to disable the use of ExtrTests
use strict;
use warnings;
use inc::Module::Install;

system($^X, 'author/generate-mouse-tiny.pl', 'lib/Mouse/Tiny.pm') == 0
    or warn "Cannot generate Mouse::Tiny: $!";

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

my $use_xs;

for (@ARGV) {
    /^--pp$/ and $use_xs = 0;
    /^--xs$/ and $use_xs = 1;
}

if($] < 5.008_001){
    $use_xs = 0;
}

if(!defined $use_xs){
    configure_requires 'ExtUtils::CBuilder';
    require ExtUtils::CBuilder;
    $use_xs = ExtUtils::CBuilder->new(quiet => 1)->have_compiler();
}

if($use_xs){
    require Module::Install::XSUtil;
    use_ppport(3.19);
    cc_warnings();
    cc_src_paths('xs-src');

    print "Mouse configured in XS (--xs)\n";
}
else{
    print "Mouse configured in Pure Perl (--pp)\n";
}

if (author_context()) {
    local @INC = ('lib', @INC);
    require 'lib/Mouse/Spec.pm';
    my $require_version = Mouse::Spec->MooseVersion;

    if (eval{ require Moose; Moose->VERSION($require_version) }) {
        if (eval 'use Module::Install::AuthorTests; 1') {
            do 'author/create-moose-compatibility-tests.pl';
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
                               .q{ "do 'author/force-pp.pl'; test_harness($(TEST_VERBOSE), '$(INST_LIB)', '$(INST_ARCHLIB)')"}
                               .q{ $(TEST_FILES)} . "\n";

        postamble qq{test_dynamic :: test_pp\n\n}
                . qq{test_pp :: pure_all\n}
                . qq{\t} . $test_via_harness;
    }
}

clean_files 'lib/Mouse/Tiny.pm';

WriteAll check_nmake => 0;
