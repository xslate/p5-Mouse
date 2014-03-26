#!perl
use strict;
use warnings;

BEGIN{
    eval  { require MRO::Compat };
    eval q{ require mro }; # avoid xt/minimum_version.t violation
}

use Test::More defined(&mro::get_linear_isa)
    ? (tests => 1)
    : (skip_all => 'This test requires mro');

{
    package Base;
    use Mouse;

    package Left;
    use Mouse;
    extends 'Base';

    package Right;
    use Mouse;
    extends 'Base';

    package Diamond;
    use Mouse;
    use mro 'c3';

    extends qw(Left Right);

}

is_deeply([Diamond->meta->linearized_isa], [qw(Diamond Left Right Base Mouse::Object)]);
