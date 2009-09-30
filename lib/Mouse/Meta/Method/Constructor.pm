package Mouse::Meta::Method::Constructor;
use strict;
use warnings;

sub generate_constructor_method_inline {
    my ($class, $metaclass) = @_;

    my $associated_metaclass_name = $metaclass->name;
    my @attrs         = $metaclass->get_all_attributes;

    my $buildall      = $class->_generate_BUILDALL($metaclass);
    my $buildargs     = $class->_generate_BUILDARGS($metaclass);
    my $processattrs  = $class->_generate_processattrs($metaclass, \@attrs);

    my @compiled_constraints = map { $_ ? $_->_compiled_type_constraint : undef }
                               map { $_->type_constraint } @attrs;

    my $code = sprintf("#line %d %s\n", __LINE__, __FILE__).<<"...";
    sub {
        my \$class = shift;
        return \$class->Mouse::Object::new(\@_)
            if \$class ne q{$associated_metaclass_name};
        $buildargs;
        my \$instance = bless {}, \$class;
        $processattrs;
        $buildall;
        return \$instance;
    }
...

    local $@;
    my $res = eval $code;
    die $@ if $@;
    $res;
}

sub _generate_processattrs {
    my ($class, $metaclass, $attrs) = @_;
    my @res;

    my $has_triggers;

    for my $index (0 .. @$attrs - 1) {
        my $attr = $attrs->[$index];
        my $key  = $attr->name;
        my $code = '';

        if (defined $attr->init_arg) {
            my $from = $attr->init_arg;

            $code .= "if (exists \$args->{q{$from}}) {\n";

            my $value = "\$args->{q{$from}}";
            if(my $type_constraint = $attr->type_constraint){
                if($attr->should_coerce && $type_constraint->has_coercion){
                    $code .= "my \$value = \$attrs[$index]->{type_constraint}->coerce(\$args->{q{$from}});\n";
                    $value = '$value';
                }

                $code .= "\$compiled_constraints[$index]->($value)\n";
                $code .= "  or \$attrs[$index]->verify_type_constraint_error(q{$key}, $value, \$attrs[$index]->{type_constraint});\n";
            }

            $code .= "\$instance->{q{$key}} = $value;\n";

            if ($attr->is_weak_ref) {
                $code .= "Scalar::Util::weaken( \$instance->{q{$key}} ) if ref($value);\n";
            }

            if ($attr->has_trigger) {
                $has_triggers++;
                $code .= "push \@triggers, [\$attrs[$index]->{trigger}, $value];\n";
            }

            $code .= "\n} else {\n";
        }

        if ($attr->has_default || $attr->has_builder) {
            unless ($attr->is_lazy) {
                my $default = $attr->default;
                my $builder = $attr->builder;

                $code .= "my \$value = ";

                if ($attr->should_coerce && $attr->type_constraint) {
                    $code .= "\$attrs[$index]->_coerce_and_verify(";
                }

                if ($attr->has_builder) {
                    $code .= "\$instance->$builder()";
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
                            \$attrs[$index]->verify_type_constraint_error(q{$key}, \$value, \$attrs[$index]->type_constraint)
                        }
                    }";
                }

                $code .= "\$instance->{q{$key}} = \$value;\n";

                if ($attr->is_weak_ref) {
                    $code .= "Scalar::Util::weaken( \$instance->{q{$key}} ) if ref( \$value );\n";
                }
            }
        }
        elsif ($attr->is_required) {
            $code .= "Carp::confess('Attribute ($key) is required');";
        }

        $code .= "}\n" if defined $attr->init_arg;

        push @res, $code;
    }

    if($metaclass->is_anon_class){
        push @res, q{$instnace->{__METACLASS__} = $metaclass;};
    }

    if($has_triggers){
        unshift @res, q{my @triggers;};
        push    @res,  q{$_->[0]->($instance, $_->[1]) for @triggers;};
    }

    return join "\n", @res;
}

sub _generate_BUILDARGS {
    my($self, $metaclass) = @_;

    if ($metaclass->name->can('BUILDARGS') && $metaclass->name->can('BUILDARGS') != \&Mouse::Object::BUILDARGS) {
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
    my ($class, $metaclass) = @_;

    return '' unless $metaclass->name->can('BUILD');

    my @code;
    for my $class ($metaclass->linearized_isa) {
        no strict 'refs';
        no warnings 'once';

        if (*{ $class . '::BUILD' }{CODE}) {
            unshift  @code, qq{${class}::BUILD(\$instance, \$args);};
        }
    }
    return join "\n", @code;
}

1;
