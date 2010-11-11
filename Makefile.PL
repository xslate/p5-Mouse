# COMPAT_TEST=1 genrates Moose compatible tests
# for developpers:
BEGIN{
    if(grep{ $_ eq '--author' } @ARGV){
        print "$^X -S cpanm < author/requires.cpanm\n";
        system "$^X -S cpanm < author/requires.cpanm";
    }
}

use strict;
use warnings;
BEGIN {
    unshift @INC, 'inc';

	# author requires, or bundled modules
    my @devmods = qw(
        inc::Module::Install             1.00
        Module::Install::TestTarget      0.13
        Module::Install::AuthorTests     0.002
        Module::Install::XSUtil          0.36
		Test::Exception::LessClever      0.005
		Test::Requires                   0.06
    );
    my @not_available;
	while(my($mod, $ver) = splice @devmods, 0, 2) {
        eval qq{use $mod $ver (); 1} or push @not_available, $mod;
    }
    if(@not_available) {
        print qq{# The following modules are not available.\n};
        print qq{# `perl $0 | cpanm` will install them:\n};
        print $_, "\n" for @not_available;
		exit 1;
     }
}
use inc::Module::Install;

all_from 'lib/Mouse.pm';

# Scalar::Util < 1.14 has a bug.
# > Fixed looks_like_number(undef) to return false for perl >= 5.009002
requires 'Scalar::Util' => 1.14;

test_requires 'Test::More' => 0.88;

# to keep zero-dependencies
include 'Test::Exception::LessClever';
include 'Test::Requires';

my %suggests = (
    'Any::Moose'                     => 0.10,

    'MouseX::AttributeHelpers'       => 0.06,
    'MouseX::NativeTraits'           => 1.00,
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
    print "Mouse configured with XS.\n";

    use_ppport(3.19);
    use_xshelper();
    cc_warnings();
    cc_src_paths('xs-src');
    if($use_xs){
		test_target test_pp => (
			env => { PERL_ONLY => 1 },
			($Module::Install::AUTHOR ? (alias => 'test') : ()),
		);
    }
}
else{
    print "Mouse configured with Pure Perl.\n";
}

tests 't/*.t t/*/*.t';
author_tests 'xt';

repository 'git://git.moose.perl.org/Mouse.git';

system($^X, 'tool/generate-mouse-tiny.pl', 'lib/Mouse/Tiny.pm') == 0
    or warn "Cannot generate Mouse::Tiny: $!";
makemaker_args PL_FILES => {
    'tool/generate-mouse-tiny.pl' => 'lib/Mouse/Tiny.pm',
};

if ($Module::Install::AUTHOR) {
    require 'lib/Mouse/Spec.pm'; # for the version
    my $require_version = Mouse::Spec->MooseVersion;

    if ($ENV{COMPAT_TEST}
            && eval { require Moose; Moose->VERSION($require_version) }) {
        print "You have Moose ", Moose->VERSION, ".\n";
        do 'tool/create-moose-compatibility-tests.pl';
        test_target test_moose => (
            tests => ['xt/compat/t/*/*.t'],
            alias => 'test',
        );
    } else {
        print "You don't have Moose $require_version. skipping moose compatibility test\n";
    }


    # Hack to disable Test::Exception, which might pull a perl internal bug.
    # See also Test::Exception::LessClever.
    open my $out, '>', 'inc/Test/Exception.pm' or die $!;
    print $out <<'EOT';
package Test::Exception; # wapper to T::E::LessClever
require Test::Exception::LessClever;
$INC{'Test/Exception.pm'} = __FILE__;
sub import {
    shift;
    Test::Exception::LessClever->export_to_level(1, @_);
}
1;
EOT
    close $out or die $!;
}

clean_files q{
    lib/Mouse/Tiny.pm $(O_FILES) test-mydeps-*.log
    *.out
    cover_db xs-src/*.gc{v,no,da}
};

WriteAll check_nmake => 0;
