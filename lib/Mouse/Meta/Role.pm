package Mouse::Meta::Role;
use strict;
use warnings;
use Carp 'confess';

do {
    my %METACLASS_CACHE;

    # because Mouse doesn't introspect existing classes, we're forced to
    # only pay attention to other Mouse classes
    sub _metaclass_cache {
        my $class = shift;
        my $name  = shift;
        return $METACLASS_CACHE{$name};
    }

    sub initialize {
        my $class = shift;
        my $name  = shift;
        $METACLASS_CACHE{$name} = $class->new(name => $name)
            if !exists($METACLASS_CACHE{$name});
        return $METACLASS_CACHE{$name};
    }
};

sub new {
    my $class = shift;
    my %args  = @_;

    $args{attributes}       ||= {};
    $args{required_methods} ||= [];
    $args{roles}            ||= [];

    bless \%args, $class;
}

sub name { $_[0]->{name} }

sub add_required_methods {
    my $self = shift;
    my @methods = @_;
    push @{$self->{required_methods}}, @methods;
}

sub add_attribute {
    my $self = shift;
    my $name = shift;
    my $spec = shift;
    $self->{attributes}->{$name} = $spec;
}

sub has_attribute { exists $_[0]->{attributes}->{$_[1]}  }
sub get_attribute_list { keys %{ $_[0]->{attributes} } }
sub get_attribute { $_[0]->{attributes}->{$_[1]} }

# copied from Class::Inspector
sub get_method_list {
    my $self = shift;
    my $name = $self->name;

    no strict 'refs';
    # Get all the CODE symbol table entries
    my @functions =
      grep !/^(?:has|with|around|before|after|blessed|extends|confess|excludes|meta|requires)$/,
      grep { defined &{"${name}::$_"} }
      keys %{"${name}::"};
    wantarray ? @functions : \@functions;
}

sub apply {
    my $self  = shift;
    my $selfname = $self->name;
    my $class = shift;
    my $classname = $class->name;
    my %args  = @_;

    if ($class->isa('Mouse::Meta::Class')) {
        for my $name (@{$self->{required_methods}}) {
            unless ($classname->can($name)) {
                confess "'$selfname' requires the method '$name' to be implemented by '$classname'";
            }
        }
    }

    {
        no strict 'refs';
        for my $name ($self->get_method_list) {
            next if $name eq 'meta';

            if ($classname->can($name)) {
                # XXX what's Moose's behavior?
                #next;
            } else {
                *{"${classname}::${name}"} = *{"${selfname}::${name}"};
            }
            if ($args{alias} && $args{alias}->{$name}) {
                my $dstname = $args{alias}->{$name};
                unless ($classname->can($dstname)) {
                    *{"${classname}::${dstname}"} = *{"${selfname}::${name}"};
                }
            }
        }
    }

    if ($class->isa('Mouse::Meta::Class')) {
        # apply role to class
        for my $name ($self->get_attribute_list) {
            next if $class->has_attribute($name);
            my $spec = $self->get_attribute($name);
            Mouse::Meta::Attribute->create($class, $name, %$spec);
        }
    } else {
        # apply role to role
        # XXX Room for speed improvement
        for my $name ($self->get_attribute_list) {
            next if $class->has_attribute($name);
            my $spec = $self->get_attribute($name);
            $class->add_attribute($name, $spec);
        }
    }

    # XXX Room for speed improvement in role to role
    for my $modifier_type (qw/before after around/) {
        my $add_method = "add_${modifier_type}_method_modifier";
        my $modified = $self->{"${modifier_type}_method_modifiers"};

        for my $method_name (keys %$modified) {
            for my $code (@{ $modified->{$method_name} }) {
                $class->$add_method($method_name => $code);
            }
        }
    }

    # append roles
    push @{ $class->roles }, $self, @{ $self->roles };
}

sub combine_apply {
    my(undef, $class, @roles) = @_;
    my $classname = $class->name;

    if ($class->isa('Mouse::Meta::Class')) {
        for my $role_spec (@roles) {
            my $self = $role_spec->[0]->meta;
            for my $name (@{$self->{required_methods}}) {
                unless ($classname->can($name)) {
                    my $method_required = 0;
                    for my $role (@roles) {
                        $method_required = 1 if $self->name ne $role->[0] && $role->[0]->can($name);
                    }
                    confess "'".$self->name."' requires the method '$name' to be implemented by '$classname'"
                        unless $method_required;
                }
            }
        }
    }

    {
        no strict 'refs';
        for my $role_spec (@roles) {
            my $self = $role_spec->[0]->meta;
            my $selfname = $self->name;
            my %args = %{ $role_spec->[1] };
            for my $name ($self->get_method_list) {
                next if $name eq 'meta';

                if ($classname->can($name)) {
                    # XXX what's Moose's behavior?
                    #next;
                } else {
                    *{"${classname}::${name}"} = *{"${selfname}::${name}"};
                }
                if ($args{alias} && $args{alias}->{$name}) {
                    my $dstname = $args{alias}->{$name};
                    unless ($classname->can($dstname)) {
                        *{"${classname}::${dstname}"} = *{"${selfname}::${name}"};
                    }
                }
            }
        }
    }


    if ($class->isa('Mouse::Meta::Class')) {
        # apply role to class
        for my $role_spec (@roles) {
            my $self = $role_spec->[0]->meta;
            for my $name ($self->get_attribute_list) {
                next if $class->has_attribute($name);
                my $spec = $self->get_attribute($name);
                Mouse::Meta::Attribute->create($class, $name, %$spec);
            }
        }
    } else {
        # apply role to role
        # XXX Room for speed improvement
        for my $role_spec (@roles) {
            my $self = $role_spec->[0]->meta;
            for my $name ($self->get_attribute_list) {
                next if $class->has_attribute($name);
                my $spec = $self->get_attribute($name);
                $class->add_attribute($name, $spec);
            }
        }
    }

    # XXX Room for speed improvement in role to role
    for my $modifier_type (qw/before after around/) {
        my $add_method = "add_${modifier_type}_method_modifier";
        for my $role_spec (@roles) {
            my $self = $role_spec->[0]->meta;
            my $modified = $self->{"${modifier_type}_method_modifiers"};

            for my $method_name (keys %$modified) {
                for my $code (@{ $modified->{$method_name} }) {
                    $class->$add_method($method_name => $code);
                }
            }
        }
    }

    # append roles
    my %role_apply_cache;
    my @apply_roles;
    for my $role_spec (@roles) {
        my $self = $role_spec->[0]->meta;
        push @apply_roles, $self unless $role_apply_cache{$self}++;
        for my $role ($self->roles) {
            push @apply_roles, $role unless $role_apply_cache{$role}++;
        }
    }
}

for my $modifier_type (qw/before after around/) {
    no strict 'refs';
    *{ __PACKAGE__ . '::' . "add_${modifier_type}_method_modifier" } = sub {
        my ($self, $method_name, $method) = @_;

        push @{ $self->{"${modifier_type}_method_modifiers"}->{$method_name} },
            $method;
    };

    *{ __PACKAGE__ . '::' . "get_${modifier_type}_method_modifiers" } = sub {
        my ($self, $method_name, $method) = @_;
        @{ $self->{"${modifier_type}_method_modifiers"}->{$method_name} || [] }
    };
}

sub roles { $_[0]->{roles} }

1;

