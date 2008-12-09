use strict;
use warnings;
use Test::More;
plan skip_all => "This test requires Moose" unless eval "require Moose; 1;";
plan tests => 6;

test($_) for qw/Moose Mouse/;
exit;

sub test {
    my $class = shift;
    eval <<"...";
{
    package ${class}Class;
    use ${class};
    sub foo { }
    no ${class};
}
{
    package ${class}ClassImm;
    use ${class};
    sub foo { }
    no ${class};
    __PACKAGE__->meta->make_immutable();
}
{
    package ${class}Role;
    use ${class}::Role;
    sub bar { }
}
...
    die $@ if $@;
    is join(',', sort "${class}Class"->meta->get_method_list()),    'foo,meta';
    is join(',', sort "${class}ClassImm"->meta->get_method_list()), 'foo,meta,new';
    is join(',', sort "${class}Role"->meta->get_method_list()),     'bar';
}

