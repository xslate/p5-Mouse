use inc::Module::Install;

name     'Mouse';
all_from 'lib/Mouse.pm';

build_requires 'Test::More';

WriteAll;

