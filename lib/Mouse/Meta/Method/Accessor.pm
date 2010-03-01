package Mouse::Meta::Method::Accessor;
use Mouse::Util qw(:meta); # enables strict and warnings
use warnings FATAL => 'recursion';

use Mouse::Meta::Method::Constructor; # for slot access

sub _generate_accessor_any{
    my($method_class, $type, $attribute, $class) = @_;

    my $c             = 'Mouse::Meta::Method::Constructor';

    my $key           = $attribute->name;
    my $default       = $attribute->default;
    my $constraint    = $attribute->type_constraint;
    my $builder       = $attribute->builder;
    my $trigger       = $attribute->trigger;
    my $is_weak       = $attribute->is_weak_ref;
    my $should_deref  = $attribute->should_auto_deref;
    my $should_coerce = (defined($constraint) && $constraint->has_coercion && $attribute->should_coerce);

    my $compiled_type_constraint = defined($constraint) ? $constraint->_compiled_type_constraint : undef;

    my $instance  = '$_[0]';
    my $slot      = $c->_inline_get_slot($instance, $key);;

    my $accessor = sprintf(<<'END_SUB_START', $class->name, __LINE__, $type, $key, __FILE__);
package %s;
#line %d "%s-accessor for %s (%s)
sub {
END_SUB_START

    if ($type eq 'rw' || $type eq 'wo') {
        if($type eq 'rw'){
            $accessor .= 
                'if (scalar(@_) >= 2) {' . "\n";
        }
        else{ # writer
            $accessor .= 
                'if(@_ < 2){ Carp::confess("Not enough arguments for the writer of '.$key.'") }'.
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
                    $attribute->_throw_type_constraint_error('.$value.', $constraint);' . "\n";
        }

        # if there's nothing left to do for the attribute we can return during
        # this setter
        $accessor .= 'return ' if !$is_weak && !$trigger && !$should_deref;

        $accessor .= $c->_inline_set_slot($instance, $key, $value) . ";\n";

        if ($is_weak) {
            $accessor .= $c->_inline_weaken_slot($instance, $key) ." if ref $slot;\n";
        }

        if ($trigger) {
            $accessor .= '$trigger->('.$instance.', '.$value.');' . "\n";
        }

        $accessor .= "}\n";
    }
    elsif($type eq 'ro') {
        $accessor .= 'Carp::confess("Cannot assign a value to a read-only accessor") if scalar(@_) >= 2;' . "\n";
    }
    else{
        $class->throw_error("Unknown accessor type '$type'");
    }

    if ($attribute->is_lazy) {
        my $value;

        if (defined $builder){
            $value = "$instance->\$builder()";
        }
        elsif (ref($default) eq 'CODE'){
            $value = "$instance->\$default()";
        }
        else{
            $value = '$default';
        }

        $accessor .= sprintf "if(!%s){\n", $c->_inline_has_slot($instance, $key);
        if($should_coerce){
            $value = "\$constraint->coerce($value)";
        }
        elsif(defined $constraint){
            $accessor .= "my \$tmp = $value;\n";

            $accessor .= "\$compiled_type_constraint->(\$tmp)";
            $accessor .= " || \$attribute->_throw_type_constraint_error(\$tmp, \$constraint);\n";
            $value = '$tmp';
        }

        $accessor .= $c->_inline_set_slot($instance, $key, $value) .";\n";

        if ($is_weak) {
            $accessor .= $c->_inline_weaken_slot($instance, $key) . " if ref $slot;\n";
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

    #print $accessor, "\n";
    my $code;
    my $e = do{
        local $@;
        $code = eval $accessor;
        $@;
    };
    die $e if $e;

    return $code;
}

sub _generate_accessor{
    my $class = shift;
    return $class->_generate_accessor_any(rw => @_);
}

sub _generate_reader {
    my $class = shift;
    return $class->_generate_accessor_any(ro => @_);
}

sub _generate_writer {
    my $class = shift;
    return $class->_generate_accessor_any(wo => @_);
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

1;
__END__

=head1 NAME

Mouse::Meta::Method::Accessor - A Mouse method generator for accessors

=head1 VERSION

This document describes Mouse version 0.50_05

=head1 SEE ALSO

L<Moose::Meta::Method::Accessor>

=cut
