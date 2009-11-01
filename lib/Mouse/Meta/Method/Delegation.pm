package Mouse::Meta::Method::Delegation;
use Mouse::Util; # enables strict and warnings
use Scalar::Util qw(blessed);

sub _generate_delegation{
    my (undef, $attribute, $metaclass, $reader, $handle_name, $method_to_call) = @_;

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

Mouse::Meta::Method::Delegation - A Mouse method generator for delegation methods

=head1 VERSION

This document describes Mouse version 0.40_04

=head1 SEE ALSO

L<Moose::Meta::Method::Delegation>

=cut
