requires 'perl', '5.008005';

# Scalar::Util < 1.14 has a bug.
# > Fixed looks_like_number(undef) to return false for perl >= 5.009002
requires 'Scalar::Util', '1.14';

requires 'XSLoader', '0.02';

on configure => sub {
    requires 'Devel::PPPort', '3.19';
    requires 'ExtUtils::ParseXS', '3.22';
    requires 'Module::Build::XSUtil';
};

on 'test' => sub {
    requires 'Test::More', '0.88';

    # Comes from author/cpanm.requires
    requires 'Test::Exception';
    requires 'Test::Exception::LessClever';
    requires 'Test::Fatal';
    requires 'Test::LeakTrace';
    requires 'Test::Output';
    requires 'Test::Requires';
    requires 'Try::Tiny';
};

on 'develop' => sub {
    # author's tests
    requires 'Test::Pod::Coverage';
    requires 'Test::DependentModules';

    # required by recipes and examples
    suggests 'Regexp::Common';
    suggests 'Locale::US';
    suggests 'HTTP::Headers';
    suggests 'Params::Coerce';
    suggests 'URI';
    suggests 'Declare::Constraints::Simple';
    suggests 'Test::Deep';
    suggests 'IO::String';
};


