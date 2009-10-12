#!/usr/bin/perl
use strict;
use warnings;
use Test::More tests => 4;
use Test::Exception;

{
    package Role;
    use Mouse::Role;

    sub rmethod{
        $_[0]->meta->throw_error('bar');
    }

    package Class;
    use Mouse;

    with 'Role';

    sub cmethod{
        $_[0]->meta->throw_error('foo');
    }
}


throws_ok {
    Class->new->cmethod();
} qr/\b foo \b/xms;

throws_ok {
    Class->cmethod();
} qr/\b foo \b/xms;



throws_ok {
    Class->new->rmethod();
} qr/\b bar \b/xms;

throws_ok {
    Class->rmethod();
} qr/\b bar \b/xms;

