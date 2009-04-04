package Mouse::Meta::Method::Accessor;
use strict;
use warnings;
use Carp ();

# internal use only. do not call directly
sub generate_accessor_method_inline {
    my ($class, $attribute) = @_;

    my $name          = $attribute->name;
    my $default       = $attribute->default;
    my $constraint    = $attribute->type_constraint;
    my $builder       = $attribute->builder;
    my $trigger       = $attribute->trigger;
    my $is_weak       = $attribute->is_weak_ref;
    my $should_deref  = $attribute->should_auto_deref;
    my $should_coerce = $attribute->should_coerce;

    my $compiled_type_constraint    = $constraint ? $constraint->{_compiled_type_constraint} : undef;

    my $self  = '$_[0]';
    my $key   = $attribute->inlined_name;

    my $accessor = 
        '#line ' . __LINE__ . ' "' . __FILE__ . "\"\n" .
        "sub {\n";
    if ($attribute->_is_metadata eq 'rw') {
        $accessor .= 
            '#line ' . __LINE__ . ' "' . __FILE__ . "\"\n" .
            'if (scalar(@_) >= 2) {' . "\n";

        my $value = '$_[1]';

        if ($constraint) {
            if ($should_coerce) {
                $accessor .=
                    "\n".
                    '#line ' . __LINE__ . ' "' . __FILE__ . "\"\n" .
                    'my $val = Mouse::Util::TypeConstraints->typecast_constraints("'.$attribute->associated_class->name.'", $attribute->{type_constraint}, '.$value.');';
                $value = '$val';
            }
            if ($compiled_type_constraint) {
                $accessor .= 
                    "\n".
                    '#line ' . __LINE__ . ' "' . __FILE__ . "\"\n" .
                    'unless ($compiled_type_constraint->('.$value.')) {
                        $attribute->verify_type_constraint_error($name, '.$value.', $attribute->{type_constraint});
                    }' . "\n";
            } else {
                $accessor .= 
                    "\n".
                    '#line ' . __LINE__ . ' "' . __FILE__ . "\"\n" .
                    'unless ($constraint->check('.$value.')) {
                        $attribute->verify_type_constraint_error($name, '.$value.', $attribute->{type_constraint});
                    }' . "\n";
            }
        }

        # if there's nothing left to do for the attribute we can return during
        # this setter
        $accessor .= 'return ' if !$is_weak && !$trigger && !$should_deref;

        $accessor .= $self.'->{'.$key.'} = '.$value.';' . "\n";

        if ($is_weak) {
            $accessor .= 'Scalar::Util::weaken('.$self.'->{'.$key.'}) if ref('.$self.'->{'.$key.'});' . "\n";
        }

        if ($trigger) {
            $accessor .= '$trigger->('.$self.', '.$value.');' . "\n";
        }

        $accessor .= "}\n";
    }
    else {
        $accessor .= 'Carp::confess("Cannot assign a value to a read-only accessor") if scalar(@_) >= 2;' . "\n";
    }

    if ($attribute->is_lazy) {
        $accessor .= $self.'->{'.$key.'} = ';

        $accessor .= $attribute->has_builder
                ? $self.'->$builder'
                    : ref($default) eq 'CODE'
                    ? '$default->('.$self.')'
                    : '$default';
        $accessor .= ' if !exists '.$self.'->{'.$key.'};' . "\n";
    }

    if ($should_deref) {
        if (ref($constraint) && $constraint->name eq 'ArrayRef') {
            $accessor .= 'if (wantarray) {
                return @{ '.$self.'->{'.$key.'} || [] };
            }';
        }
        else {
            $accessor .= 'if (wantarray) {
                return %{ '.$self.'->{'.$key.'} || {} };
            }';
        }
    }

    $accessor .= 'return '.$self.'->{'.$key.'};
    }';

    my $sub = eval $accessor;
    Carp::confess($@) if $@;
    return $sub;
}

1;
