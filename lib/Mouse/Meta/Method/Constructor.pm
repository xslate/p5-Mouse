package Mouse::Meta::Method::Constructor;
use strict;
use warnings;

sub generate_constructor_method_inline {
    my ($class, $meta) = @_;

    my @attrs = $meta->compute_all_applicable_attributes; # this one is using by evaled code
    my $buildall = $class->_generate_BUILDALL($meta);
    my $buildargs = $class->_generate_BUILDARGS();
    my $processattrs = $class->_generate_processattrs($meta, \@attrs);

    my $code = <<"...";
    sub {
        my \$class = shift;
        my \$args = $buildargs;
        my \$instance = bless {}, \$class;
        $processattrs;
        $buildall;
        return \$instance;
    }
...

    warn $code if $ENV{DEBUG};

    local $@;
    my $res = eval $code;
    die $@ if $@;
    $res;
}

sub _generate_processattrs {
    my ($class, $meta, $attrs) = @_;
    my @res;
    for my $index (0..scalar(@$attrs)-1) {
        my $attr = $attrs->[$index];
        my $from = $attr->init_arg;
        my $key  = $attr->name;

        my $set_value = do {
            my @code;

            if ($attr->should_coerce) {
                push @code, "my \$value = \$attr->coerce_constraint( \$args->{'$from'});";
            }
            else {
                push @code, "my \$value = \$args->{'$from'};";
            }

            if ($attr->has_type_constraint) {
                push @code, "\$attr->verify_type_constraint( \$value );";
            }

            push @code, "\$instance->{'$key'} = \$value;";

            if ($attr->is_weak_ref) {
                push @code, "weaken( \$instance->{'$key'} ) if ref( \$value );";
            }

            if ( $attr->has_trigger ) {
                push @code, "\$attr->trigger->( \$instance, \$value, \$attr );";
            }

            join "\n", @code;
        };

        my $make_default_value = do {
            my @code;

            if ( $attr->has_default || $attr->has_builder ) {
                unless ( $attr->is_lazy ) {
                    my $default = $attr->default;
                    my $builder = $attr->builder;

                    push @code, "my \$value = ";

                    if ($attr->should_coerce) {
                        push @code, "\$attr->coerce_constraint(";
                    }

                        if ($attr->has_builder) {
                            push @code, "\$instance->$builder";
                        }
                        elsif (ref($default) eq 'CODE') {
                            push @code, "\$attr->default()->()";
                        }
                        else {
                            push @code, "\$attr->default()";
                        }

                    if ($attr->should_coerce) {
                        push @code, ");";
                    }
                    else {
                        push @code, ";";
                    }

                    if ($attr->has_type_constraint) {
                        push @code, "\$attr->verify_type_constraint(\$value);";
                    }

                    push @code, "\$instance->{'$key'} = \$value;";

                    if ($attr->is_weak_ref) {
                        push @code, "weaken( \$instance->{'$key'} ) if ref( \$value );";
                    }
                }
                join "\n", @code;
            }
            else {
                if ( $attr->is_required ) {
                    qq{Carp::confess("Attribute ($key) is required");};
                } else {
                    ""
                }
            }
        };
        my $code = <<"...";
            {
                my \$attr = \$attrs[$index];
                if (exists(\$args->{'$from'})) {
                    $set_value;
                } else {
                    $make_default_value;
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
