use strict;
use warnings;
use Test::More;
plan skip_all => "This test requires Moose" unless eval "require Moose; 1;";
plan tests => 4;

test('Moose');
test('Mouse');
exit;

sub test {
    my $class = shift;
    eval <<"...";
{
    package ${class}Parent;
    use ${class};
    sub parent_method { 'ok' }
}

{
    package ${class}ChildRole;
    use ${class}::Role;
    use base qw/${class}Parent/;
    sub conflict { "role's" }
}

{
    package ${class}Class;
    use ${class};
    with '${class}ChildRole';
    sub conflict { "class's" }
}
...
    die $@ if $@;
    ok !"${class}Class"->can('parent_method');
    is "${class}Class"->conflict(), "class's";
}

