#!perl -w
BEGIN{ $^P = 0x10 | 0x200 }
use Test::More;

sub DB::DB {}

{
    package Foo;
    use Mouse;

    __PACKAGE__->meta->add_method(bar => sub{ __LINE__ });
}

if(Mouse::Util::MOUSE_XS){
is $DB::sub{'Foo::bar'}, sprintf('%s:%d-%d', __FILE__, Foo->bar, Foo->bar),
    '%DB::sub updated';
}
else{
    pass 'under Mouse::PurePerl';
}

done_testing;
