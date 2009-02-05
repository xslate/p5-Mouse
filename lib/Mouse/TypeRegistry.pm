package Mouse::TypeRegistry;
use Mouse::Util::TypeConstraints;

sub import {
    warn "Mouse::TypeRegistry is deprecated, please use Mouse::Util::TypeConstraints instead.";

    shift @_;
    unshift @_, 'Mouse::Util::TypeConstraints';
    goto \&Mouse::Util::TypeConstraints::import;
}

sub unimport {
    warn "Mouse::TypeRegistry is deprecated, please use Mouse::Util::TypeConstraints instead.";

    shift @_;
    unshift @_, 'Mouse::Util::TypeConstraints';
    goto \&Mouse::Util::TypeConstraints::unimport;
}

1;

