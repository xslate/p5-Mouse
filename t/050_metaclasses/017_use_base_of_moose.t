#!/usr/bin/env perl

use strict;
use warnings;
use Test::More;

BEGIN{
    if($] < 5.008){
        plan skip_all => "segv happens on 5.6.2";
    }
}

use Test::More tests => 4;
use Test::Exception;

{
    package NoOpTrait;
    use Mouse::Role;


}

{
    package Parent;
    use Mouse "-traits" => 'NoOpTrait';

    has attr => (
        is  => 'rw',
        isa => 'Str',
    );
}

{
    package Child;
    use base 'Parent';
}
is(Child->meta->name, 'Child', "correct metaclass name");
my $child = Child->new(attr => "ibute");
ok($child, "constructor works");


is($child->attr, "ibute", "getter inherited properly");

$child->attr("ition");
is($child->attr, "ition", "setter inherited properly");
