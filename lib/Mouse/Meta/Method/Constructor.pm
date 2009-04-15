package Mouse::Meta::Method::Constructor;
use strict;
use warnings;

sub generate_constructor_method_inline {
    my ($class, $meta) = @_;

    my $associated_metaclass_name = $meta->name;
    my @attrs = $meta->get_all_attributes;
    my $buildall = $class->_generate_BUILDALL($meta);
    my $buildargs = $class->_generate_BUILDARGS($meta);
    my $processattrs = $class->_generate_processattrs($meta, \@attrs);
    my @compiled_constraints = map { $_ ? $_->{_compiled_type_constraint} : undef } map { $_->{type_constraint} } @attrs;

    my $code = <<"...";
    sub {
        my \$class = shift;
        return \$class->Mouse::Object::new(\@_)
            if \$class ne '$associated_metaclass_name';
        $buildargs;
        my \$instance = bless {}, \$class;
        $processattrs;
        $buildall;
        return \$instance;
    }
...

    local $@;
    # warn $code;
    my $res = eval $code;
    die $@ if $@;
    $res;
}

sub _generate_processattrs {
    my ($class, $meta, $attrs) = @_;
    my @res;

    for my $index (0 .. @$attrs - 1) {
        my $attr = $attrs->[$index];
        my $key  = $attr->name;
        my $code = '';

        if (defined $attr->init_arg) {
            my $from = $attr->init_arg;

            $code .= "if (exists \$args->{'$from'}) {\n";

            if ($attr->should_coerce && $attr->type_constraint) {
                $code .= "my \$value = Mouse::Util::TypeConstraints->typecast_constraints('".$attr->associated_class->name."', \$attrs[$index]->{type_constraint}, \$args->{'$from'});\n";
            }
            else {
                $code .= "my \$value = \$args->{'$from'};\n";
            }

            if ($attr->has_type_constraint) {
                if ($attr->type_constraint->{_compiled_type_constraint}) {
                    $code .= "unless (\$compiled_constraints[$index](\$value)) {";
                } else {
                    $code .= "unless (\$attrs[$index]->{type_constraint}->check(\$value)) {";
                }
                $code .= "
                        \$attrs[$index]->verify_type_constraint_error(
                            '$key', \$value, \$attrs[$index]->type_constraint
                        )
                    }
                ";
            }

            $code .= "\$instance->{'$key'} = \$value;\n";

            if ($attr->is_weak_ref) {
                $code .= "Scalar::Util::weaken( \$instance->{'$key'} ) if ref( \$value );\n";
            }

            if ($attr->has_trigger) {
                $code .= "\$attrs[$index]->{trigger}->( \$instance, \$value );\n";
            }

            $code .= "\n} else {\n";
        }

        if ($attr->has_default || $attr->has_builder) {
            unless ($attr->is_lazy) {
                my $default = $attr->default;
                my $builder = $attr->builder;

                $code .= "my \$value = ";

                if ($attr->should_coerce && $attr->type_constraint) {
                    $code .= "Mouse::Util::TypeConstraints->typecast_constraints('".$attr->associated_class->name."', \$attrs[$index]->{type_constraint}, ";
                }

                    if ($attr->has_builder) {
                        $code .= "\$instance->$builder";
                    }
                    elsif (ref($default) eq 'CODE') {
                        $code .= "\$attrs[$index]->{default}->(\$instance)";
                    }
                    elsif (!defined($default)) {
                        $code .= 'undef';
                    }
                    elsif ($default =~ /^\-?[0-9]+(?:\.[0-9]+)$/) {
                        $code .= $default;
                    }
                    else {
                        $code .= "'$default'";
                    }

                if ($attr->should_coerce) {
                    $code .= ");\n";
                }
                else {
                    $code .= ";\n";
                }

                if ($attr->has_type_constraint) {
                    $code .= "{
                        unless (\$attrs[$index]->{type_constraint}->check(\$value)) {
                            \$attrs[$index]->verify_type_constraint_error('$key', \$value, \$attrs[$index]->type_constraint)
                        }
                    }";
                }

                $code .= "\$instance->{'$key'} = \$value;\n";

                if ($attr->is_weak_ref) {
                    $code .= "Scalar::Util::weaken( \$instance->{'$key'} ) if ref( \$value );\n";
                }
            }
        }
        elsif ($attr->is_required) {
            $code .= "Carp::confess('Attribute ($key) is required');";
        }

        $code .= "}\n" if defined $attr->init_arg;

        push @res, $code;
    }

    return join "\n", @res;
}

sub _generate_BUILDARGS {
    my $self = shift;
    my $meta = shift;

    if ($meta->name->can('BUILDARGS') && $meta->name->can('BUILDARGS') != Mouse::Object->can('BUILDARGS')) {
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
    my ($class, $meta) = @_;
    return '' unless $meta->name->can('BUILD');

    my @code = ();
    push @code, q{no strict 'refs';};
    push @code, q{no warnings 'once';};
    no strict 'refs';
    no warnings 'once';
    for my $klass ($meta->linearized_isa) {
        if (*{ $klass . '::BUILD' }{CODE}) {
            unshift  @code, qq{${klass}::BUILD(\$instance, \$args);};
        }
    }
    return join "\n", @code;
}

1;
