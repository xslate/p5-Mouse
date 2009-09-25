package Mouse::Meta::Method::Destructor;
use strict;
use warnings;

sub generate_destructor_method_inline {
    my ($class, $meta) = @_;

    my $demolishall = do {
        if ($meta->name->can('DEMOLISH')) {
            my @code = ();
            for my $class ($meta->linearized_isa) {
                no strict 'refs';
                if (*{$class . '::DEMOLISH'}{CODE}) {
                    push @code, "${class}::DEMOLISH(\$self);";
                }
            }
            join "\n", @code;
        } else {
            return sub { }; # no demolish =)
        }
    };

    my $code = <<"...";
    sub {
        my \$self = shift;
        $demolishall;
    }
...

    local $@;
    my $res = eval $code;
    die $@ if $@;
    return $res;
}

1;
