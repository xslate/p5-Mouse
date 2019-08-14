use strict;
use warnings;

use Test::More;

{
    package SuperClass;

    sub foo { 1 }
}

{
    package AdditionalRole;
    use Mouse::Role;

    sub added { 1 }

    no Mouse::Role;
}

{
    package MyClass;

    use Mouse;
    use MouseX::Foreign 'SuperClass';
}

sub foo {
    my $obj = MyClass->new();
    AdditionalRole->meta->apply($obj);
    return 1;
}

for my $i (1..10) {
    subtest "try $i" => sub {
        ok foo(), "apply role";
    };
}

done_testing;
