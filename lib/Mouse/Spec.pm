package Mouse::Spec;
use strict;
use warnings;

our $VERSION = '0.37_05';

our $MouseVersion = $VERSION;
our $MooseVersion = '0.90';

sub MouseVersion{ $MouseVersion }
sub MooseVersion{ $MooseVersion }

1;
__END__

=head1 NAME

Mouse::Spec - To what extent Mouse is compatible with Moose

=head1 DESCRIPTION

=head2 Notes about Moose::Cookbook

Many recipes in L<Moose::Cookbook> fit L<Mouse>, including:

=over 4

=item *

L<Moose::Cookbook::Basics::Recipe1> - The (always classic) B<Point> example

=item *

L<Moose::Cookbook::Basics::Recipe2> - A simple B<BankAccount> example

=item *

L<Moose::Cookbook::Basics::Recipe3> - A lazy B<BinaryTree> example

=item *

L<Moose::Cookbook::Basics::Recipe4> - Subtypes, and modeling a simple B<Company> class hierarchy

=item *

L<Moose::Cookbook::Basics::Recipe5> - More subtypes, coercion in a B<Request> class

=item *

L<Moose::Cookbook::Basics::Recipe6> - The augment/inner example

=item *

L<Moose::Cookbook::Basics::Recipe7> - Making Moose fast with immutable

=item *

L<Moose::Cookbook::Basics::Recipe8> - Builder methods and lazy_build

=item *

L<Moose::Cookbook::Basics::Recipe9> - Operator overloading, subtypes, and coercion

=item *

L<Moose::Cookbook::Basics::Recipe10> - Using BUILDARGS and BUILD to hook into object construction

=item *

L<Moose::Cookbook::Roles::Recipe1> - The Moose::Role example

=item *

L<Moose::Cookbook::Roles::Recipe2> - Advanced Role Composition - method exclusion and aliasing

=item *

L<Moose::Cookbook::Roles::Recipe3> - Applying a role to an object instance

=item *

L<Moose::Cookbook::Meta::Recipe2> - A meta-attribute, attributes with labels

=item *

L<Moose::Cookbook::Meta::Recipe3> - Labels implemented via attribute traits

=item *

L<Moose::Cookbook::Extending::Recipe3> - Providing an alternate base object class

=back

=head1 SEE ALSO

L<Mouse>

=cut

