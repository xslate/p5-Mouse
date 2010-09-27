package Base;
use Any::Moose;

has [qw(aaa bbb ccc)] => (
    is => 'rw',
);

package D1;
use Any::Moose;
extends qw(Base);
has [qw(ddd eee fff)] => (
    is => 'rw',
);

package D2;
use Any::Moose;
extends qw(D1);
has [qw(ggg hhh iii)] => (
    is => 'rw',
);

package main;
use Test::More;
use Test::Mouse;

with_immutable {
    my $attrs_list = join ",",
        map { $_->name } D2->meta->get_all_attributes;
    is $attrs_list, join ",", qw(aaa bbb ccc ddd eee fff ggg hhh iii);
} qw(Base D1 D2);
done_testing;
