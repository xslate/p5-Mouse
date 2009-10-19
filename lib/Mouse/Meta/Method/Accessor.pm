package Mouse::Meta::Method::Accessor;
use Mouse::Util; # enables strict and warnings
use Scalar::Util qw(blessed);

sub _generate_accessor{
    my (undef, $attribute, $class, $type) = @_;

    my $name          = $attribute->name;
    my $default       = $attribute->default;
    my $constraint    = $attribute->type_constraint;
    my $builder       = $attribute->builder;
    my $trigger       = $attribute->trigger;
    my $is_weak       = $attribute->is_weak_ref;
    my $should_deref  = $attribute->should_auto_deref;
    my $should_coerce = (defined($constraint) && $constraint->has_coercion && $attribute->should_coerce);

    my $compiled_type_constraint = defined($constraint) ? $constraint->_compiled_type_constraint : undef;

    my $self  = '$_[0]';
    my $key   = "q{$name}";
    my $slot  = "$self\->{$key}";

    $type ||= 'accessor';

    my $accessor = sprintf(qq{#line 1 "%s for %s (%s)"\n}, $type, $name, __FILE__)
                 . "sub {\n";

    if ($type eq 'accessor' || $type eq 'writer') {
        if($type eq 'accessor'){
            $accessor .= 
                'if (scalar(@_) >= 2) {' . "\n";
        }
        else{ # writer
            $accessor .= 
                'if(@_ < 2){ Carp::confess("Not enough arguments for the writer of '.$name.'") }'.
                '{' . "\n";
        }
                
        my $value = '$_[1]';

        if (defined $constraint) {
            if ($should_coerce) {
                $accessor .=
                    "\n".
                    'my $val = $constraint->coerce('.$value.');';
                $value = '$val';
            }
            $accessor .= 
                "\n".
                '$compiled_type_constraint->('.$value.') or
                    $attribute->verify_type_constraint_error($name, '.$value.', $constraint);' . "\n";
        }

        # if there's nothing left to do for the attribute we can return during
        # this setter
        $accessor .= 'return ' if !$is_weak && !$trigger && !$should_deref;

        $accessor .= "$slot = $value;\n";

        if ($is_weak) {
            $accessor .= "Scalar::Util::weaken($slot) if ref $slot;\n";
        }

        if ($trigger) {
            $accessor .= '$trigger->('.$self.', '.$value.');' . "\n";
        }

        $accessor .= "}\n";
    }
    elsif($type eq 'reader') {
        $accessor .= 'Carp::confess("Cannot assign a value to a read-only accessor") if scalar(@_) >= 2;' . "\n";
    }
    else{
        $class->throw_error("Unknown accessor type '$type'");
    }

    if ($attribute->is_lazy) {
        my $value;

        if (defined $builder){
            $value = "$self->\$builder()";
        }
        elsif (ref($default) eq 'CODE'){
            $value = "$self->\$default()";
        }
        else{
            $value = '$default';
        }

        $accessor .= "if(!exists $slot){\n";
        if($should_coerce){
            $accessor .= "$slot = \$constraint->coerce($value)";
        }
        elsif(defined $constraint){
            $accessor .= "my \$tmp = $value;\n";
            #XXX: The following 'defined and' check is for backward compatibility
            $accessor .= "defined(\$tmp) and ";

            $accessor .= "\$compiled_type_constraint->(\$tmp)";
            $accessor .= " || \$attribute->verify_type_constraint_error(\$name, \$tmp, \$constraint);\n";
            $accessor .= "$slot = \$tmp;\n";
        }
        else{
            $accessor .= "$slot = $value;\n";
        }
        $accessor .= "}\n";
    }

    if ($should_deref) {
        if ($constraint->is_a_type_of('ArrayRef')) {
            $accessor .= "return \@{ $slot || [] } if wantarray;\n";
        }
        elsif($constraint->is_a_type_of('HashRef')){
            $accessor .= "return \%{ $slot || {} } if wantarray;\n";
        }
        else{
            $class->throw_error("Can not auto de-reference the type constraint " . $constraint->name);
        }
    }

    $accessor .= "return $slot;\n}\n";

    #print "# class ", $class->name, "\n", $accessor, "\n";
    my $code;
    my $e = do{
        local $@;
        $code = eval $accessor;
        $@;
    };
    die $e if $e;

    return $code;
}

sub _generate_reader{
    my $class = shift;
    return $class->_generate_accessor(@_, 'reader');
}

sub _generate_writer{
    my $class = shift;
    return $class->_generate_accessor(@_, 'writer');
}


sub _generate_predicate {
    my (undef, $attribute, $class) = @_;

    my $slot = $attribute->name;
    return sub{
        return exists $_[0]->{$slot};
    };
}

sub _generate_clearer {
    my (undef, $attribute, $class) = @_;

    my $slot = $attribute->name;

   return sub{
        delete $_[0]->{$slot};
    };
}

sub _generate_delegation{
    my (undef, $attribute, $class, $reader, $handle_name, $method_to_call) = @_;

    return sub {
        my $instance = shift;
        my $proxy    = $instance->$reader();

        my $error = !defined($proxy)                ? ' is not defined'
                  : ref($proxy) && !blessed($proxy) ? qq{ is not an object (got '$proxy')}
                                                    : undef;
        if ($error) {
            $instance->meta->throw_error(
                "Cannot delegate $handle_name to $method_to_call because "
                    . "the value of "
                    . $attribute->name
                    . $error
             );
        }
        $proxy->$method_to_call(@_);
    };
}


1;
__END__

=head1 NAME

Mouse::Meta::Method::Accessor - A Mouse method generator for accessors

=head1 VERSION

This document describes Mouse version 0.40

=head1 SEE ALSO

L<Moose::Meta::Method::Accessor>

=cut
