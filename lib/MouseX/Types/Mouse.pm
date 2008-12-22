package MouseX::Types::Mouse;
use strict;
use warnings;

BEGIN { require Mouse::Util::TypeConstraints }
use MouseX::Types;

BEGIN {
    my $builtin_type = +{ map { $_ => $_ } Mouse::Util::TypeConstraints->list_all_builtin_type_constraints };
    sub type_storage { $builtin_type }
}

1;


