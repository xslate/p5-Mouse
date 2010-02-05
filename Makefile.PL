use strict;
use warnings;
use inc::Module::Install;

# for co-developpers
use Module::Install::XSUtil 0.21;

system($^X, 'tool/generate-mouse-tiny.pl', 'lib/Mouse/Tiny.pm') == 0
    or warn "Cannot generate Mouse::Tiny: $!";

name     'Mouse';
all_from 'lib/Mouse.pm';

# Scalar::Util < 1.14 has a bug.
# > Fixed looks_like_number(undef) to return false for perl >= 5.009002
requires 'Scalar::Util' => 1.14;

test_requires 'Test::More'      => 0.88;
test_requires 'Test::Exception' => 0.29;
# test_requires 'Test::Output'    => 0.16; # too many dependencies!

if($] < 5.010) {
    recommends 'Class::C3';
}

my %suggests = (
    'Class::Method::Modifiers::Fast' => 0.041,
    'MouseX::AttributeHelpers'       => 0.06,
);

while(my($mod, $least) = each %suggests){
    if(can_use($mod)){
        if(!eval { $mod->VERSION($least) }){
            my $ver = $mod->VERSION;
            warn("\n",
                "WARNING: $mod is installed, but its version ($ver) is too old (< $least).\n",
                "         Please update $mod after installation of Mouse.\n",
                "\n"
            );
        }
    }
}

require 'lib/Mouse/Spec.pm'; # for the version

#if(Mouse::Spec->MouseVersion =~ /_/){ # DEVEL RELEASE
#    require Carp::Always; Carp::Always->import();
#    include_deps 'Carp::Always';
#}

# cc_available recognizes the '--pp' and '--xs' options
my $use_xs = ($] >= 5.008_001 && cc_available());

if($use_xs){
    print "Mouse configured with XS.\n",
          "NOTE: You can try --pp option to configure Mouse with Pure Perl.\n";

    cc_warnings();
    use_ppport(3.19);
    cc_src_paths('xs-src');
}
else{
    print "Mouse configured with Pure Perl.\n";
}


tests 't/*.t t/*/*.t';
author_tests 'xt';


repository 'git://git.moose.perl.org/Mouse.git';

clean_files 'lib/Mouse/Tiny.pm $(O_FILES)';


if (author_context()) {
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


WriteAll check_nmake => 0;
