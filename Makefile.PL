use inc::Module::Install;

name     'Mouse';
all_from 'lib/Mouse.pm';

tests 't/*.t t/*/*.t';

build_requires 'Test::Exception';
build_requires 'Sub::Uplevel';    # required by Test::Exception
build_requires 'Test::More';

auto_include;

WriteMakefile(
	OBJECT => '$(O_FILES)',
	clean => {
		FILES => q{
			*.stackdump
			*.gcov *.gcda *.gcno
			*.out
			nytprof
			cover_db
		},
	},

);
