#!/usr/bin/perl

use strict;
use warnings;

use Test::More tests => 16;
use Test::Exception;

use Mouse::Meta::Role::Application::RoleSummation;
use Mouse::Meta::Role::Composite;

{
    package Role::Foo;
    use Mouse::Role;    
    requires 'foo';
    
    package Role::Bar;
    use Mouse::Role;
    requires 'bar';
    
    package Role::ProvidesFoo;
    use Mouse::Role;    
    sub foo { 'Role::ProvidesFoo::foo' }
    
    package Role::ProvidesBar;
    use Mouse::Role;    
    sub bar { 'Role::ProvidesBar::bar' }     
}

# test simple requirement
{
    my $c = Mouse::Meta::Role::Composite->new(
        roles => [
            Role::Foo->meta,
            Role::Bar->meta,
        ]        
    );
    isa_ok($c, 'Mouse::Meta::Role::Composite');

    is($c->name, 'Role::Foo|Role::Bar', '... got the composite role name');    
    
    lives_ok {
        Mouse::Meta::Role::Application::RoleSummation->new->apply($c);
    } '... this succeeds as expected';    
    
    is_deeply(
        [ sort $c->get_required_method_list ],
        [ 'bar', 'foo' ],
        '... got the right list of required methods'
    );
}

# test requirement satisfied
{
    my $c = Mouse::Meta::Role::Composite->new(
        roles => [
            Role::Foo->meta,
            Role::ProvidesFoo->meta,
        ]
    );
    isa_ok($c, 'Mouse::Meta::Role::Composite');

    is($c->name, 'Role::Foo|Role::ProvidesFoo', '... got the composite role name');    
    
    lives_ok { 
        Mouse::Meta::Role::Application::RoleSummation->new->apply($c);
    } '... this succeeds as expected';    
    
    is_deeply(
        [ sort $c->get_required_method_list ],
        [],
        '... got the right list of required methods'
    );
}

# test requirement satisfied
{
    my $c = Mouse::Meta::Role::Composite->new(
        roles => [
            Role::Foo->meta,
            Role::ProvidesFoo->meta,
            Role::Bar->meta,            
        ]
    );
    isa_ok($c, 'Mouse::Meta::Role::Composite');

    is($c->name, 'Role::Foo|Role::ProvidesFoo|Role::Bar', '... got the composite role name');    
    
    lives_ok {
        Mouse::Meta::Role::Application::RoleSummation->new->apply($c);
    } '... this succeeds as expected';    
    
    is_deeply(
        [ sort $c->get_required_method_list ],
        [ 'bar' ],
        '... got the right list of required methods'
    );
}

# test requirement satisfied
{
    my $c = Mouse::Meta::Role::Composite->new(
        roles => [
            Role::Foo->meta,
            Role::ProvidesFoo->meta,
            Role::ProvidesBar->meta,            
            Role::Bar->meta,            
        ]
    );
    isa_ok($c, 'Mouse::Meta::Role::Composite');

    is($c->name, 'Role::Foo|Role::ProvidesFoo|Role::ProvidesBar|Role::Bar', '... got the composite role name');    
    
    lives_ok {
        Mouse::Meta::Role::Application::RoleSummation->new->apply($c);
    } '... this succeeds as expected';    
    
    is_deeply(
        [ sort $c->get_required_method_list ],
        [ ],
        '... got the right list of required methods'
    );
}


