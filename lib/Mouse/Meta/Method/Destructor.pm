package Mouse::Meta::Method::Destructor;
use Mouse::Util qw(:meta); # enables strict and warnings

sub _generate_destructor{
    my (undef, $metaclass) = @_;

    my $demolishall = '';
    for my $class ($metaclass->linearized_isa) {
        if (Mouse::Util::get_code_ref($class, 'DEMOLISH')) {
            $demolishall .= sprintf "%s::DEMOLISH(\$self, \$Mouse::Util::in_global_destruction);\n",
                $class,
        }
    }

    my $name   = $metaclass->name;
    my $source = sprintf(<<'EOT', __LINE__, __FILE__, $name, $demolishall);
#line %d %s
    package %s;
    sub {
        my $self = shift;
        return $self->Mouse::Object::DESTROY()
            if ref($self) ne __PACKAGE__;
        my $e = do{
            local $?;
            local $@;
            eval{
                # demolishall
                %s;
            };
            $@;
        };
        no warnings 'misc';
        die $e if $e; # rethrow
    }
EOT

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

Mouse::Meta::Method::Destructor - A Mouse method generator for destructors

=head1 VERSION

This document describes Mouse version 0.72

=head1 SEE ALSO

L<Moose::Meta::Method::Destructor>

=cut
