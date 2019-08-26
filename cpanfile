requires 'perl', '5.008005';

# Scalar::Util < 1.14 has a bug.
# > Fixed looks_like_number(undef) to return false for perl >= 5.009002
requires 'Scalar::Util', '1.14';

requires 'XSLoader', '0.02';

conflicts 'Any::Moose', '< 0.10';
conflicts 'MouseX::AttributeHelpers', '< 0.06';
conflicts 'MouseX::NativeTraits', '< 1.00';

on configure => sub {
    requires 'Devel::PPPort', '3.42';
    requires 'ExtUtils::ParseXS', '3.22';
    requires 'Module::Build::XSUtil', '0.19';
    # prevent "Mouse::Deprecated does not define $VERSION" error in test under perl 5.8
    requires 'version', '0.9913';
};

on 'test' => sub {
    requires 'Test::More', '0.88';
    requires 'Test::Exception';
    requires 'Test::Fatal';
    requires 'Test::LeakTrace';
    requires 'Test::Output';
    requires 'Test::Requires';
    requires 'Try::Tiny';
};

on 'develop' => sub {
    requires 'Test::Pod::Coverage';
    requires 'Test::DependentModules';
    suggests 'Regexp::Common';
    suggests 'Locale::US';
    suggests 'HTTP::Headers';
    suggests 'Params::Coerce';
    suggests 'URI';
    suggests 'Declare::Constraints::Simple';
    suggests 'Test::Deep';
    suggests 'IO::String';
};
