use strict;
use warnings;
use Test::More tests => 2;

# Klass->does_role should check the parent classes.

{
    package R1;
    use Mouse::Role;
}

{
    package C1;
    use Mouse;
    with 'R1';
}

{
    package C2;
    use Mouse;
    extends 'C1';
}

ok(C1->meta->does_role('R1'));
ok(C2->meta->does_role('R1'));

