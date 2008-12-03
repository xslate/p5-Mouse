package Mouse::Meta::Method::Constructor;
use strict;
use warnings;

sub generate_constructor_method_inline {
    my ($class, $meta) = @_; 
    my $buildall = $class->_generate_BUILDALL($meta);
    my $buildargs = $class->_generate_BUILDARGS();
    my $classname = $meta->name;
    my $processattrs = $class->_generate_processattrs($meta);

    my $code = <<"...";
    sub {
        my \$class = shift;
        my \$args = $buildargs;
        my \$instance = bless {}, '$classname';
        $processattrs;
        $buildall;
        return \$instance;
    }
...
    warn $code if $ENV{DEBUG};

    my $res = eval $code;
    die $@ if $@;
    $res;
}

sub _generate_processattrs {
    my ($class, $meta, ) = @_;
    my @attrs = $meta->compute_all_applicable_attributes;
    my @res;
    for my $attr (@attrs) {
        my $from = $attr->init_arg;
        my $key  = $attr->name;
        my $part1 = do {
            my @code;
            if ($attr->should_coerce) {
                push @code, "\$args->{\$from} = \$attr->coerce_constraint( \$args->{\$from} );";
            }
            if ($attr->has_type_constraint) {
                push @code, "\$attr->verify_type_constraint( \$args->{\$from} );";
            }
            push @code, "\$instance->{\$key} = \$args->{\$from};";
            push @code, "weaken( \$instance->{\$key} ) if ref( \$instance->{\$key} ) && \$attr->is_weak_ref;";
            if ( $attr->has_trigger ) {
                push @code, "\$attr->trigger->( \$instance, \$args->{\$from}, \$attr );";
            }
            join "\n", @code;
        };
        my $part2 = do {
            my @code;
            if ( $attr->has_default || $attr->has_builder ) {
                unless ( $attr->is_lazy ) {
                    my $default = $attr->default;
                    my $builder = $attr->builder;
                    if ($attr->has_builder) {
                        push @code, "my \$value = \$instance->$builder;";
                    } elsif (ref($default) eq 'CODE') {
                        push @code, "my \$value = \$attr->default()->();";
                    } else {
                        push @code, "my \$value = \$attr->default();";
                    }
                    if ($attr->should_coerce) {
                        push @code, "\$value = \$attr->coerce_constraint(\$value);";
                    }
                    if ($attr->has_type_constraint) {
                        push @code, "\$attr->verify_type_constraint(\$value);";
                    }
                    push @code, "\$instance->{\$key} = \$value;";
                    if ($attr->is_weak_ref) {
                        push @code, "weaken( \$instance->{\$key} ) if ref( \$instance->{\$key} );";
                    }
                }
                join "\n", @code;
            }
            else {
                if ( $attr->is_required ) {
                    q{Carp::confess("Attribute (} . $attr->name . q{) is required");};
                } else {
                    ""
                }
            }
        };
        my $code = <<"...";
            {
                my \$attr = \$instance->meta->get_attribute_map->{'$key'};
                my \$from = '$from';
                my \$key  = '$key';
                if (defined(\$from) && exists(\$args->{\$from})) {
                    $part1;
                } else {
                    $part2;
                }
            }
...
        push @res, $code;
    }
    return join "\n", @res;
}

sub _generate_BUILDARGS {
    <<'...';
    do {
        if ( scalar @_ == 1 ) {
            if ( defined $_[0] ) {
                ( ref( $_[0] ) eq 'HASH' )
                || Carp::confess "Single parameters to new() must be a HASH ref";
                +{ %{ $_[0] } };
            }
            else {
                +{};
            }
        }
        else {
            +{@_};
        }
    };
...
}

sub _generate_BUILDALL {
    my ($class, $meta) = @_;
    return '' unless $meta->name->can('BUILD');

    my @code = ();
    push @code, q{no strict 'refs';};
    push @code, q{no warnings 'once';};
    no strict 'refs';
    for my $class ($meta->linearized_isa) {
        if (*{ $class . '::BUILD' }{CODE}) {
            push  @code, qq{${class}::BUILD->(\$instance, \$args);};
        }
    }
    return join "\n", @code;
}

1;
