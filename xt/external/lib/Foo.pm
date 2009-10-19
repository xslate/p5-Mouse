package Foo;
use Mouse;

has foo => (
    is => 'ro',
    isa => 'Str',
);

has bar => (
    is => 'ro',
    isa => 'Str',
);

no Mouse;
__PACKAGE__->meta->make_immutable;
__END__

=head1 NAME

Foo - bar

=head1 ATTRIBUTES

=over 4

=item foo

=back

=cut
