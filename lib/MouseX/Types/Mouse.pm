package MouseX::Types::Mouse;
use strict;
use warnings;

BEGIN { require Mouse::TypeRegistry }
use MouseX::Types;

BEGIN {
    my $builtin_type = +{ map { $_ => $_ } Mouse::TypeRegistry->list_all_builtin_type_constraints };
    sub type_storage { $builtin_type }
}

1;


