package Mouse::Meta::Method::Destructor;
use Mouse::Util; # enables strict and warnings

sub _empty_DESTROY{ }

sub _generate_destructor{
    my (undef, $metaclass) = @_;

    if(!$metaclass->name->can('DEMOLISH')){
        return \&_empty_DESTROY;
    }

    my $demolishall = '';
    for my $class ($metaclass->linearized_isa) {
        no strict 'refs';
        no warnings 'once';
        if (*{$class . '::DEMOLISH'}{CODE}) {
            $demolishall .= "${class}::DEMOLISH(\$self);\n";
        }
    }

    my $source = sprintf("#line %d %s\n", __LINE__, __FILE__) . <<"...";
    sub {
        my \$self = shift;
        local \$?;

        my \$e = do{
            local \$@;
            eval{
                $demolishall;
            };
            \$@;
        };
        no warnings 'misc';
        die \$e if \$e; # rethrow
    }
...

    my $code;
    my $e = do{
        local $@;
        $code = eval $source;
        $@;
    };
    die $e if $e;
    return $code;
}

1;
__END__

=head1 NAME

Mouse::Meta::Method::Accessor - A Mouse method generator for destructors

=head1 VERSION

This document describes Mouse version 0.40

=head1 SEE ALSO

L<Moose::Meta::Method::Destructor>

=cut
