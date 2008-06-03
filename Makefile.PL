use inc::Module::Install;

name     'Mouse';
all_from 'lib/Mouse.pm';

requires 'Sub::Exporter';
requires 'Scalar::Util';
requires 'MRO::Compat';

build_requires 'Test::More';
build_requires 'Test::Exception';
build_requires 'Test::Warn';

WriteAll;

