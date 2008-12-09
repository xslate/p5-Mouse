use inc::Module::Install;

name     'Mouse';
all_from 'lib/Mouse.pm';

tests 't/*.t t/*/*.t';

if ($] < 5.007003) {
    requires 'Scalar::Util';
}

build_requires 'Test::Exception';
build_requires 'Test::More';

auto_include;
WriteAll;
