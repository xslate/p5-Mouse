#!perl

use constant NEED_TESTING => $ENV{RELEASE_TESTING} || (grep { $_ eq '--test' } @ARGV);
use if !NEED_TESTING, 'Test::More' => (skip_all => "for release testing");

use strict;
use warnings;
use Test::Requires qw(Test::DependentModules);
use Test::More;

use Test::DependentModules qw(test_module);
# To avoid circular dependencies, set recommends_policy = 0
Test::DependentModules::_load_cpan();
$CPAN::Config->{recommends_policy} = 0;

use Cwd qw(abs_path);

note("Testing user modules which depend on Mouse");

$ENV{PERL_TEST_DM_LOG_DIR} = abs_path('.');
delete $ENV{ANY_MOOSE}; # use Mouse by default

my @modules = qw(
    MouseX::Types
    MouseX::Types::Path::Class

    MouseX::AttributeHelpers
    MouseX::ConfigFromFile
);

test_module($_) for @modules;

done_testing;

__END__
# TODO
BEGIN{
    $ENV{PERL5OPT}       = '-Mblib' if exists $INC{'blib.pm'};
    #$ENV{PERL_CPANM_DEV} = 1;
}

use strict;
use warnings;
use Test::Requires qw(App::cpanminus::script);
use Test::More;

BEGIN{
    package Test::UserModules;
    our @ISA = qw(App::cpanminus::script);

    sub init {
        my($self) = @_;
        $self->hook('test_user_modules', 'install_success' => \&_install_success);
        $self->hook('test_user_modules', 'build_failure'   => \&_build_failure);
        $self->SUPER::init();
    }

    sub log {
        my($self, @messages) = @_;
        #Test::More->builder->note(@messages);
        return;
    }

    sub _install_success {
        my($args) = @_;
        Test::More->builder->ok(1, "install $args->{module}");
    }

    sub _build_failure {
        my($args) = @_;
        Test::More->builder->ok(0, "install $args->{module} ($args->{message})");
    }
}

# See also http://cpants.perl.org/dist/used_by/Any-Moose

my @user_modules = qw(
    MouseX::Types
    MouseX::Types::Path::Class

    MouseX::AttributeHelpers
    MouseX::Getopt
    MouseX::ConfigFromFile

    Any::Moose

    HTTP::Engine
    HTTP::Engine::Middleware

    git://github.com/typester/ark-perl.git
    HTML::Shakan
    Net::Google::API
);

my $t = Test::UserModules->new();
$t->parse_options(@user_modules);
$t->doit();


done_testing;
