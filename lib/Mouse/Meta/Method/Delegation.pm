package Mouse::Meta::Method::Delegation;
use Mouse::Util qw(:meta); # enables strict and warnings
use Scalar::Util;

sub _generate_delegation{
    my (undef, $attribute, $handle_name, $method_to_call) = @_;

    my $reader = $attribute->get_read_method_ref();
    return sub {
        my $instance = shift;
        my $proxy    = $instance->$reader();

        my $error = !defined($proxy)                              ? ' is not defined'
                  : ref($proxy) && !Scalar::Util::blessed($proxy) ? qq{ is not an object (got '$proxy')}
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

This document describes Mouse version 0.47

=head1 SEE ALSO

L<Moose::Meta::Method::Delegation>

=cut
