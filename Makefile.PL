use inc::Module::Install;

name     'Mouse';
all_from 'lib/Mouse.pm';

tests 't/*.t t/*/*.t';

# Scalar::Util < 1.14 has a bug.
# > Fixed looks_like_number(undef) to return false for perl >= 5.009002
requires 'Scalar::Util' => 1.14;

build_requires 'Test::Exception';
build_requires 'Test::More';

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
}

auto_include;
WriteAll;

sub create_moose_compatibility_test {
    require File::Path;
    require File::Spec;
    require File::Basename;

    # some test does not pass... currently skip it.
    my %SKIP_TEST = (
        '016-trigger.t'    => "trigger's argument is incompatble :(",
        '020-load-class.t' => "&Moose::is_class_loaded doesn't exists",
        '019-handles.t'    => 'incompatible',
        '025-more-isa.t'   => 'Class::MOP::is_class_loaded is not compatible with Mouse::is_class_loaded',
        '029-new.t'        => 'Class->new(undef) incompatible',
        '010-isa-or.t'     => 'Mouse has a [BUG]',
        '044-attribute-metaclass.t' => 'Moose::Meta::Attribute does not have a "create"',
        '047-attribute-metaclass-role.t' => 'Moose::Meta::Attribute does not have a "create"',
        '201-squirrel.t'      => 'skip Squirrel',
        '202-squirrel-role.t' => 'Squirrel is ...',
        '400-define-role.t'   => 'incompatibility',
        '600-tiny-tiny.t'     => "Moose doesn't support ::Tiny",
        '601-tiny-mouse.t'    => "Moose doesn't support ::Tiny",
        '602-mouse-tiny.t'    => "Moose doesn't support ::Tiny",
        '031_roles_applied_in_create.t' => 'wtf?',
    );

    File::Find::find(
        {
            wanted => sub {
                return unless -f $_;
                my $basename = File::Basename::basename($_);
                return if $basename =~ /^\./;
                return if $SKIP_TEST{$basename};
                
                my $dirname = File::Basename::dirname($_);

                my $tmpdir = File::Spec->catfile('xt', 'compatibility', $dirname);
                File::Path::make_path($tmpdir);

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
                    $src =~ s/Mouse/Moose/g;
                    $src;
                };
                close $wfh;
            },
            no_chdir => 1
        },
        't',
    );
}

