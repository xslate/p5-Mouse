use inc::Module::Install;

name     'Mouse';
all_from 'lib/Mouse.pm';

tests 't/*.t t/*/*.t';

if ($] < 5.008004) {
    # Scalar::Util < 1.14 has a bug.
    # > Fixed looks_like_number(undef) to return false for perl >= 5.009002
    requires 'Scalar::Util' => 1.14;
}

build_requires 'Test::Exception';
build_requires 'Test::More';

auto_include;
WriteAll;
