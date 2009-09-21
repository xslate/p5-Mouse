package Mouse::Meta::Role;
use strict;
use warnings;

use Mouse::Util qw(not_supported);
use base qw(Mouse::Meta::Module);

sub method_metaclass(){ 'Mouse::Meta::Role::Method' } # required for get_method()

sub _new {
    my $class = shift;
    my %args  = @_;

    $args{methods}          ||= {};
    $args{attributes}       ||= {};
    $args{required_methods} ||= [];
    $args{roles}            ||= [];

    bless \%args, $class;
}

sub get_roles { $_[0]->{roles} }

sub get_required_method_list{
    return @{ $_[0]->{required_methods} };
}

sub add_required_methods {
    my $self = shift;
    my @methods = @_;
    push @{$self->{required_methods}}, @methods;
}

sub requires_method {
    my($self, $name) = @_;
    return scalar( grep{ $_ eq $name } @{ $self->{required_methods} } ) != 0;
}

sub add_attribute {
    my $self = shift;
    my $name = shift;

    $self->{attributes}->{$name} = (@_ == 1) ? $_[0] : { @_ };
}

sub _check_required_methods{
    my($role, $class, $args, @other_roles) = @_;

    if($class->isa('Mouse::Meta::Class')){
        my $class_name = $class->name;
        foreach my $method_name(@{$role->{required_methods}}){
            unless($class_name->can($method_name)){
                my $role_name       = $role->name;
                my $has_method      = 0;

                foreach my $another_role_spec(@other_roles){
                    my $another_role_name = $another_role_spec->[0];
                    if($role_name ne $another_role_name && $another_role_name->can($method_name)){
                        $has_method = 1;
                        last;
                    }
                }
                
                $role->throw_error("'$role_name' requires the method '$method_name' to be implemented by '$class_name'")
                    unless $has_method;
            }
        }
    }

    return;
}

sub _apply_methods{
    my($role, $class, $args) = @_;

    my $role_name  = $role->name;
    my $class_name = $class->name;

    my $alias    = (exists $args->{alias}    && !exists $args->{-alias})    ? $args->{alias}    : $args->{-alias};
    my $excludes = (exists $args->{excludes} && !exists $args->{-excludes}) ? $args->{excludes} : $args->{-excludes};

    my %exclude_map;

    if(defined $excludes){
        if(ref $excludes){
            %exclude_map = map{ $_ => undef } @{$excludes};
        }
        else{
            $exclude_map{$excludes} = undef;
        }
    }

    foreach my $method_name($role->get_method_list){
        next if $method_name eq 'meta';

        my $code = $role_name->can($method_name);

        if(!exists $exclude_map{$method_name}){
            if(!$class->has_method($method_name)){
                $class->add_method($method_name => $code);
            }
        }

        if($alias && $alias->{$method_name}){
            my $dstname = $alias->{$method_name};

            my $slot = do{ no strict 'refs'; \*{$class_name . '::' . $dstname} };
            if(defined(*{$slot}{CODE}) && *{$slot}{CODE} != $code){
                $class->throw_error("Cannot create a method alias if a local method of the same name exists");
            }
            else{
                $class->add_method($dstname => $code);
            }
        }
    }

    return;
}

sub _apply_attributes{
    my($role, $class, $args) = @_;

    if ($class->isa('Mouse::Meta::Class')) {
        # apply role to class
        for my $attr_name ($role->get_attribute_list) {
            next if $class->has_attribute($attr_name);

            my $spec = $role->get_attribute($attr_name);

            my $attr_metaclass = 'Mouse::Meta::Attribute';
            if ( my $metaclass_name = $spec->{metaclass} ) {
                $attr_metaclass = Mouse::Util::resolve_metaclass_alias(
                    'Attribute',
                    $metaclass_name
                );
            }

            $attr_metaclass->create($class, $attr_name => %$spec);
        }
    } else {
        # apply role to role
        for my $attr_name ($role->get_attribute_list) {
            next if $class->has_attribute($attr_name);

            my $spec = $role->get_attribute($attr_name);
            $class->add_attribute($attr_name => $spec);
        }
    }

    return;
}

sub _apply_modifiers{
    my($role, $class, $args) = @_;

    for my $modifier_type (qw/before after around override/) {
        my $add_modifier = "add_${modifier_type}_method_modifier";
        my $modifiers    = $role->{"${modifier_type}_method_modifiers"};

        while(my($method_name, $modifier_codes) = each %{$modifiers}){
            foreach my $code(ref($modifier_codes) eq 'ARRAY' ? @{$modifier_codes} : $modifier_codes){
                $class->$add_modifier($method_name => $code);
            }
        }
    }
    return;
}

sub _append_roles{
    my($role, $class, $args) = @_;

    my $roles = $class->isa('Mouse::Meta::Class') ? $class->roles : $class->get_roles;

    foreach my $r($role, @{$role->get_roles}){
        if(!$class->does_role($r->name)){
            push @{$roles}, $r;
        }
    }
    return;
}

# Moose uses Application::ToInstance, Application::ToClass, Application::ToRole
sub apply {
    my($self, $class, %args) = @_;

    if ($class->isa('Mouse::Object')) {
        not_supported 'Application::ToInstance';
    }

    $self->_check_required_methods($class, \%args);
    $self->_apply_methods($class, \%args);
    $self->_apply_attributes($class, \%args);
    $self->_apply_modifiers($class, \%args);
    $self->_append_roles($class, \%args);
    return;
}

sub combine_apply {
    my(undef, $class, @roles) = @_;

    foreach my $role_spec (@roles) {
        my($role_name, $args) = @{$role_spec};

        my $role = $role_name->meta;

        $role->_check_required_methods($class, $args, @roles);
        $role->_apply_methods($class, $args);
        $role->_apply_attributes($class, $args);
        $role->_apply_modifiers($class, $args);
        $role->_append_roles($class, $args);
    }
    return;
}

for my $modifier_type (qw/before after around/) {

    my $modifier = "${modifier_type}_method_modifiers";
    my $add_method_modifier =  sub {
        my ($self, $method_name, $method) = @_;

        push @{ $self->{$modifier}->{$method_name} ||= [] }, $method;
        return;
    };
    my $has_method_modifiers = sub{
        my($self, $method_name) = @_;
        my $m = $self->{$modifier}->{$method_name};
        return $m && @{$m} != 0;
    };
    my $get_method_modifiers = sub {
        my ($self, $method_name) = @_;
        return @{ $self->{$modifier}->{$method_name} ||= [] }
    };

    no strict 'refs';
    *{ 'add_' . $modifier_type . '_method_modifier'  } = $add_method_modifier;
    *{ 'has_' . $modifier_type . '_method_modifiers' } = $has_method_modifiers;
    *{ 'get_' . $modifier_type . '_method_modifiers' } = $get_method_modifiers;
}

sub add_override_method_modifier{
    my($self, $method_name, $method) = @_;

    (!$self->has_method($method_name))
        || $self->throw_error("Cannot add an override of method '$method_name' " .
                   "because there is a local version of '$method_name'");

    $self->{override_method_modifiers}->{$method_name} = $method;
}

sub has_override_method_modifier {
    my ($self, $method_name) = @_;
    return exists $self->{override_method_modifiers}->{$method_name};
}

sub get_override_method_modifier {
    my ($self, $method_name) = @_;
    return $self->{override_method_modifiers}->{$method_name};
}

sub get_method_modifier_list {
    my($self, $modifier_type) = @_;

    return keys %{ $self->{$modifier_type . '_method_modifiers'} };
}

# This is currently not passing all the Moose tests.
sub does_role {
    my ($self, $role_name) = @_;

    (defined $role_name)
        || $self->throw_error("You must supply a role name to look for");

    # if we are it,.. then return true
    return 1 if $role_name eq $self->name;
    # otherwise.. check our children
    for my $role (@{ $self->get_roles }) {
        return 1 if $role->does_role($role_name);
    }
    return 0;
}


1;

