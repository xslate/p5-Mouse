package Mouse::Meta::Role;
use strict;
use warnings;

use Mouse::Util qw(:meta not_supported english_list);
use Mouse::Meta::Module;
our @ISA = qw(Mouse::Meta::Module);

sub method_metaclass(){ 'Mouse::Meta::Role::Method' } # required for get_method()

sub _construct_meta {
    my $class = shift;

    my %args  = @_;

    $args{methods}          ||= {};
    $args{attributes}       ||= {};
    $args{required_methods} ||= [];
    $args{roles}            ||= [];

#    return Mouse::Meta::Class->initialize($class)->new_object(%args)
#        if $class ne __PACKAGE__;

    return bless \%args, ref($class) || $class;
}

sub create_anon_role{
    my $self = shift;
    return $self->create(undef, @_);
}

sub is_anon_role{
    return exists $_[0]->{anon_serial_id};
}

sub get_roles { $_[0]->{roles} }

sub get_required_method_list{
    return @{ $_[0]->{required_methods} };
}

sub add_required_methods {
    my($self, @methods) = @_;
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

sub _canonicalize_apply_args{
    my($self, $applicant, %args) = @_;

    if($applicant->isa('Mouse::Meta::Class')){
        $args{_to} = 'class';
    }
    elsif($applicant->isa('Mouse::Meta::Role')){
        $args{_to} = 'role';
    }
    else{
        $args{_to} = 'instance';

        not_supported 'Application::ToInstance';
    }

    if($args{alias} && !exists $args{-alias}){
        $args{-alias} = $args{alias};
    }
    if($args{excludes} && !exists $args{-excludes}){
        $args{-excludes} = $args{excludes};
    }

    if(my $excludes = $args{-excludes}){
        $args{-excludes} = {}; # replace with a hash ref
        if(ref $excludes){
            %{$args{-excludes}} = (map{ $_ => undef } @{$excludes});
        }
        else{
            $args{-excludes}{$excludes} = undef;
        }
    }

    return \%args;
}

sub _check_required_methods{
    my($role, $class, $args, @other_roles) = @_;

    if($args->{_to} eq 'class'){
        my $class_name = $class->name;
        my $role_name  = $role->name;
        my @missing;
        foreach my $method_name(@{$role->{required_methods}}){
            if(!$class_name->can($method_name)){
                my $has_method      = 0;

                foreach my $another_role_spec(@other_roles){
                    my $another_role_name = $another_role_spec->[0];
                    if($role_name ne $another_role_name && $another_role_name->can($method_name)){
                        $has_method = 1;
                        last;
                    }
                }

                push @missing, $method_name if !$has_method;
            }
        }
        if(@missing){
            $class->throw_error("'$role_name' requires the "
                . (@missing == 1 ? 'method' : 'methods')
                . " "
                . english_list(map{ sprintf q{'%s'}, $_ } @missing)
                . " to be implemented by '$class_name'");
        }
    }
    elsif($args->{_to} eq 'role'){
        # apply role($role) to role($class)
        foreach my $method_name($role->get_required_method_list){
            next if $class->has_method($method_name); # already has it
            $class->add_required_methods($method_name);
        }
    }

    return;
}

sub _apply_methods{
    my($role, $class, $args) = @_;

    my $role_name  = $role->name;
    my $class_name = $class->name;

    my $alias    = $args->{-alias};
    my $excludes = $args->{-excludes};

    foreach my $method_name($role->get_method_list){
        next if $method_name eq 'meta';

        my $code = $role_name->can($method_name);

        if(!exists $excludes->{$method_name}){
            if(!$class->has_method($method_name)){
                $class->add_method($method_name => $code);
            }
        }

        if($alias && $alias->{$method_name}){
            my $dstname = $alias->{$method_name};

            my $dstcode = do{ no strict 'refs'; *{$class_name . '::' . $dstname}{CODE} };

            if(defined($dstcode) && $dstcode != $code){
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

    if ($args->{_to} eq 'class') {
        # apply role to class
        for my $attr_name ($role->get_attribute_list) {
            next if $class->has_attribute($attr_name);

            my $spec = $role->get_attribute($attr_name);

            $class->add_attribute($attr_name => %{$spec});
        }
    }
    elsif($args->{_to} eq 'role'){
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

    for my $modifier_type (qw/override before around after/) {
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

    my $roles = ($args->{_to} eq 'class') ? $class->roles : $class->get_roles;

    foreach my $r($role, @{$role->get_roles}){
        if(!$class->does_role($r->name)){
            push @{$roles}, $r;
        }
    }
    return;
}

# Moose uses Application::ToInstance, Application::ToClass, Application::ToRole
sub apply {
    my $self      = shift;
    my $applicant = shift;

    my $args = $self->_canonicalize_apply_args($applicant, @_);

    $self->_check_required_methods($applicant, $args);
    $self->_apply_methods($applicant, $args);
    $self->_apply_attributes($applicant, $args);
    $self->_apply_modifiers($applicant, $args);
    $self->_append_roles($applicant, $args);
    return;
}

sub combine_apply {
    my(undef, $class, @roles) = @_;

    if($class->isa('Mouse::Object')){
        not_supported 'Application::ToInstance';
    }

    # check conflicting
    my %method_provided;
    my @method_conflicts;
    my %attr_provided;
    my %override_provided;

    foreach my $role_spec (@roles) {
        my $role      = $role_spec->[0]->meta;
        my $role_name = $role->name;

        # methods
        foreach my $method_name($role->get_method_list){
            next if $class->has_method($method_name); # manually resolved

            my $code = do{ no strict 'refs'; \&{ $role_name . '::' . $method_name } };

            my $c = $method_provided{$method_name};

            if($c && $c->[0] != $code){
                push @{$c}, $role;
                push @method_conflicts, $c;
            }
            else{
                $method_provided{$method_name} = [$code, $method_name, $role];
            }
        }

        # attributes
        foreach my $attr_name($role->get_attribute_list){
            my $attr = $role->get_attribute($attr_name);
            my $c    = $attr_provided{$attr_name};
            if($c && $c != $attr){
                $class->throw_error("We have encountered an attribute conflict with '$attr_name' "
                                   . "during composition. This is fatal error and cannot be disambiguated.")
            }
            else{
                $attr_provided{$attr_name} = $attr;
            }
        }

        # override modifiers
        foreach my $method_name($role->get_method_modifier_list('override')){
            my $override = $role->get_override_method_modifier($method_name);
            my $c        = $override_provided{$method_name};
            if($c && $c != $override){
                $class->throw_error( "We have encountered an 'override' method conflict with '$method_name' during "
                                   . "composition (Two 'override' methods of the same name encountered). "
                                   . "This is fatal error.")
            }
            else{
                $override_provided{$method_name} = $override;
            }
        }
    }
    if(@method_conflicts){
        my $error;

        if(@method_conflicts == 1){
            my($code, $method_name, @roles) = @{$method_conflicts[0]};
            $class->throw_error(
                sprintf q{Due to a method name conflict in roles %s, the method '%s' must be implemented or excluded by '%s'},
                    english_list(map{ sprintf q{'%s'}, $_->name } @roles), $method_name, $class->name
            );
        }
        else{
            @method_conflicts = sort { $a->[0] cmp $b->[0] } @method_conflicts; # to avoid hash-ordering bugs
            my $methods = english_list(map{ sprintf q{'%s'}, $_->[1] } @method_conflicts);
            my $roles   = english_list(
                map{ sprintf q{'%s'}, $_->name }
                map{ my($code, $method_name, @roles) = @{$_}; @roles } @method_conflicts
            );

            $class->throw_error(
                sprintf q{Due to method name conflicts in roles %s, the methods %s must be implemented or excluded by '%s'},
                    $roles, $methods, $class->name
            );
        }
    }

    foreach my $role_spec (@roles) {
        my($role_name, $args) = @{$role_spec};

        my $role = $role_name->meta;

        $args = $role->_canonicalize_apply_args($class, %{$args});

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

    if($self->has_method($method_name)){
        # This error happens in the override keyword or during role composition,
        # so I added a message, "A local method of ...", only for compatibility (gfx)
        $self->throw_error("Cannot add an override of method '$method_name' "
                   . "because there is a local version of '$method_name'"
                   . "(A local method of the same name as been found)");
    }

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

__END__

=head1 NAME

Mouse::Meta::Role - The Mouse Role metaclass

=head1 SEE ALSO

L<Moose::Meta::Role>

=cut
