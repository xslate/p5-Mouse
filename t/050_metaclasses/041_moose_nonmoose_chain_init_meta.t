use strict;
use warnings;
use Test::More tests => 1;
use Test::Exception;

{
    package ParentClass;
    use Mouse;
}
{
    package SomeClass;
    use base 'ParentClass';
}
{
    package SubClassUseBase;
    use base qw/SomeClass/;
    use Mouse;
}

lives_ok {
    Mouse->init_meta(for_class => 'SomeClass');
} 'Mouse class => use base => Mouse Class, then Mouse->init_meta on middle class ok';
