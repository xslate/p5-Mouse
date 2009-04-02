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
    require Path::Class;
    Path::Class->import('file', 'dir');

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

    dir('t')->recurse(
        callback => sub {
            my $f = shift;
            return if $f->is_dir;
            return if $f =~ /\.sw[po]$/;
            return if $SKIP_TEST{$f->basename};

            my $dstfile = dir('xt', 'compatibility')->file($f);
            $dstfile->dir->mkpath();

            my $fh = $dstfile->openw();
            $fh->print(do {
                local $_ = $f->slurp;
                s/Mouse/Moose/g;
                $_;
            });
            $fh->close();
        },
    );
}

