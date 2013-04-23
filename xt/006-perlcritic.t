use strict;
use Test::More;
eval {
    require Perl::Critic;
    Perl::Critic->VERSION(1.105);

    require Test::Perl::Critic;
    Test::Perl::Critic->import( -profile => \join q{}, <DATA>);
};
plan skip_all => "Test::Perl::Critic is not installed." if $@;
all_critic_ok('lib');

__END__
exclude=ProhibitStringyEval ProhibitExplicitReturnUndef RequireBarewordIncludes ProhibitAccessOfPrivateData 

[TestingAndDebugging::ProhibitNoStrict]
allow=refs

[TestingAndDebugging::RequireUseStrict]
equivalent_modules = Mouse Mouse::Exporter Mouse::Util Mouse::Util::TypeConstraints

[TestingAndDebugging::RequireUseWarnings]
equivalent_modules = Mouse Mouse::Exporter Mouse::Util Mouse::Util::TypeConstraints
