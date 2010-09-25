#!perl -w
use strict;
use Benchmark qw(:all);
{
    package MyMoose;
    use Moose;
    has [qw(foo bar baz)] => (
        is      => 'rw',
        isa     => 'Str',
        default => 'qux',
    );
    __PACKAGE__->meta->make_immutable();
}
{
    package MyMouse;
    use Mouse;
    has [qw(foo bar baz)] => (
        is      => 'rw',
        isa     => 'Str',
        default => 'qux',
    );
    __PACKAGE__->meta->make_immutable();
}
print "Class->meta->new_object x 10\n";
cmpthese -1, {
    Moose => sub {
        MyMoose->meta->new_object() for 10;
    },
    Mouse => sub {
        MyMouse->meta->new_object() for 10;
    },
};

