package Mouse::Meta::Method::Constructor;
use Mouse::Util qw(:meta); # enables strict and warnings

sub _inline_create_instance {
    my(undef, $class_expr) = @_;
    return "bless {}, $class_expr";
}

sub _inline_slot {
    my(undef, $self_var, $attr_name) = @_;
    return sprintf '%s->{q{%s}}', $self_var, $attr_name;
}

sub _inline_has_slot {
    my($class, $self_var, $attr_name) = @_;

    return sprintf 'exists(%s)', $class->_inline_slot($self_var, $attr_name);
}

sub _inline_get_slot {
    my($class, $self_var, $attr_name) = @_;

    return $class->_inline_slot($self_var, $attr_name);
}

sub _inline_set_slot {
    my($class, $self_var, $attr_name, $rvalue) = @_;

    return $class->_inline_slot($self_var, $attr_name) . " = $rvalue";
}

sub _inline_weaken_slot {
    my($class, $self_var, $attr_name) = @_;

    return sprintf 'Scalar::Util::weaken(%s)', $class->_inline_slot($self_var, $attr_name);
}

sub _generate_constructor {
    my ($class, $metaclass, $args) = @_;

    my @attrs         = $metaclass->get_all_attributes;

    my $init_attrs    = $class->_generate_processattrs($metaclass, \@attrs);
    my $buildargs     = $class->_generate_BUILDARGS($metaclass);
    my $buildall      = $class->_generate_BUILDALL($metaclass);

    my @checks = map { $_ && $_->_compiled_type_constraint }
                 map { $_->type_constraint } @attrs;

    my $class_name  = $metaclass->name;
    my $source = sprintf(<<'END_CONSTRUCTOR', $class_name, __LINE__, __FILE__, $class_name, $buildargs, $class->_inline_create_instance('$class'), $init_attrs, $buildall);
package %s;
#line %d "constructor of %s (%s)"
        sub {
            my $class = shift;
            return $class->Mouse::Object::new(@_)
                if $class ne __PACKAGE__;
            # BUILDARGS
            %s;
            # create instance
            my $instance = %s;
            # process attributes
            %s;
            # BUILDALL
            %s;
            return $instance;
        }
END_CONSTRUCTOR
    #warn $source;
    my $code;
    my $e = do{
        local $@;
        $code = eval $source;
        $@;
    };
    die $e if $e;
    return $code;
}

sub _generate_processattrs {
    my ($method_class, $metaclass, $attrs) = @_;
    my @res;

    my $has_triggers;
    my $strict = $metaclass->__strict_constructor;

    if($strict){
        push @res, 'my $used = 0;';
    }

    for my $index (0 .. @$attrs - 1) {
        my $code = '';

        my $attr = $attrs->[$index];
        my $key  = $attr->name;

        my $init_arg        = $attr->init_arg;
        my $type_constraint = $attr->type_constraint;
        my $is_weak_ref     = $attr->is_weak_ref;
        my $need_coercion;

        my $instance       = '$instance';
        my $instance_slot  = $method_class->_inline_get_slot($instance, $key);
        my $attr_var       = "\$attrs[$index]";
        my $constraint_var;

        if(defined $type_constraint){
             $constraint_var = "$attr_var\->{type_constraint}";
             $need_coercion  = ($attr->should_coerce && $type_constraint->has_coercion);
        }

        $code .= "# initialize $key\n";

        my $post_process = '';
        if(defined $type_constraint){
            $post_process .= "\$checks[$index]->($instance_slot)";
            $post_process .= "  or $attr_var->_throw_type_constraint_error($instance_slot, $constraint_var);\n";
        }
        if($is_weak_ref){
            $post_process .= $method_class->_inline_weaken_slot($instance, $key) . " if ref $instance_slot;\n";
        }

        if (defined $init_arg) {
            my $value = "\$args->{q{$init_arg}}";

            $code .= "if (exists $value) {\n";

            if($need_coercion){
                $value = "$constraint_var->coerce($value)";
            }

            $code .= $method_class->_inline_set_slot($instance, $key, $value) . ";\n";
            $code .= $post_process;

            if ($attr->has_trigger) {
                $has_triggers++;
                $code .= "push \@triggers, [$attr_var\->{trigger}, $instance_slot];\n";
            }

            if ($strict){
                $code .= '++$used;' . "\n";
            }

            $code .= "\n} else {\n"; # $value exists
        }

        if ($attr->has_default || $attr->has_builder) {
            unless ($attr->is_lazy) {
                my $default = $attr->default;
                my $builder = $attr->builder;

                my $value;
                if (defined($builder)) {
                    $value = "\$instance->$builder()";
                }
                elsif (ref($default) eq 'CODE') {
                    $value = "$attr_var\->{default}->(\$instance)";
                }
                elsif (defined($default)) {
                    $value = "$attr_var\->{default}";
                }
                else {
                    $value = 'undef';
                }

                if($need_coercion){
                    $value = "$constraint_var->coerce($value)";
                }

                $code .= $method_class->_inline_set_slot($instance, $key, $value) . ";\n";
                if($is_weak_ref){
                    $code .= $method_class->_inline_weaken_slot($instance, $key) . ";\n";
                }
            }
        }
        elsif ($attr->is_required) {
            $code .= "Carp::confess('Attribute ($key) is required');";
        }

        $code .= "}\n" if defined $init_arg;

        push @res, $code;
    }

    if($strict){
        push @res, q{if($used < keys %{$args})}
            . sprintf q{{ %s->_report_unknown_args($metaclass, \@attrs, $args) }}, $method_class;
    }

    if($metaclass->is_anon_class){
        push @res, q{$instance->{__METACLASS__} = $metaclass;};
    }

    if($has_triggers){
        unshift @res, q{my @triggers;};
        push    @res, q{$_->[0]->($instance, $_->[1]) for @triggers;};
    }

    return join "\n", @res;
}

sub _generate_BUILDARGS {
    my(undef, $metaclass) = @_;

    my $class = $metaclass->name;
    if ( $class->can('BUILDARGS') && $class->can('BUILDARGS') != \&Mouse::Object::BUILDARGS ) {
        return 'my $args = $class->BUILDARGS(@_)';
    }

    return <<'...';
        my $args;
        if ( scalar @_ == 1 ) {
            ( ref( $_[0] ) eq 'HASH' )
                || Carp::confess "Single parameters to new() must be a HASH ref";
            $args = +{ %{ $_[0] } };
        }
        else {
            $args = +{@_};
        }
...
}

sub _generate_BUILDALL {
    my (undef, $metaclass) = @_;

    return '' unless $metaclass->name->can('BUILD');

    my @code;
    for my $class ($metaclass->linearized_isa) {
        if (Mouse::Util::get_code_ref($class, 'BUILD')) {
            unshift  @code, qq{${class}::BUILD(\$instance, \$args);};
        }
    }
    return join "\n", @code;
}

sub _report_unknown_args {
    my(undef, $metaclass, $attrs, $args) = @_;

    my @unknowns;
    my %init_args;
    foreach my $attr(@{$attrs}){
        my $init_arg = $attr->init_arg;
        if(defined $init_arg){
            $init_args{$init_arg}++;
        }
    }

    while(my $key = each %{$args}){
        if(!exists $init_args{$key}){
            push @unknowns, $key;
        }
    }

    $metaclass->throw_error( sprintf
        "Unknown attribute passed to the constructor of %s: %s",
        $metaclass->name, Mouse::Util::english_list(@unknowns),
    );
}

1;
__END__

=head1 NAME

Mouse::Meta::Method::Constructor - A Mouse method generator for constructors

=head1 VERSION

This document describes Mouse version 0.50_06

=head1 SEE ALSO

L<Moose::Meta::Method::Constructor>

=cut
