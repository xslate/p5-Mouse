use inc::Module::Install;

name     'Mouse';
all_from 'lib/Mouse.pm';

requires 'Sub::Exporter';
requires 'Scalar::Util';
requires 'MRO::Compat';
requires 'Class::Method::Modifiers' => '1.01';

build_requires 'Test::More';
build_requires 'Test::Exception';

WriteAll;

