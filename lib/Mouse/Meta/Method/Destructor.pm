package Mouse::Meta::Method::Destructor;
use strict;
use warnings;

sub _empty_destroy{ }

sub _generate_destructor_method {
    my ($class, $metaclass) = @_;

    my $demolishall = do {
        if ($metaclass->name->can('DEMOLISH')) {
            my @code = ();
            for my $class ($metaclass->linearized_isa) {
                no strict 'refs';
                if (*{$class . '::DEMOLISH'}{CODE}) {
                    push @code, "${class}::DEMOLISH(\$self);";
                }
            }
            join "\n", @code;
        } else {
            $metaclass->add_method(DESTROY => \&_empty_destroy);
            return;
        }
    };

    my $destructor_name = $metaclass->name . '::DESTROY';
    my $code = sprintf("#line %d %s\n", __LINE__, __FILE__) . <<"...";
    sub $destructor_name \{
        my \$self = shift;
        $demolishall;
    }
...

    my $e = do{
        local $@;
        eval $code;
        $@;
    };
    die $@ if $@;
    return;
}

1;
