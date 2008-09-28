#!/usr/bin/env perl
package Mouse::Role;
use strict;
use warnings;
use base 'Exporter';

use Carp 'confess';
use Mouse::Util 'blessed';

use Mouse::Meta::Role;

our @EXPORT = qw(before after around has extends with requires excludes confess blessed);

sub before {
    my $meta = Mouse::Meta::Role->initialize(caller);

    my $code = pop;
    for (@_) {
        $meta->add_before_method_modifier($_ => $code);
    }
}

sub after {
    my $meta = Mouse::Meta::Role->initialize(caller);

    my $code = pop;
    for (@_) {
        $meta->add_after_method_modifier($_ => $code);
    }
}

sub around {
    my $meta = Mouse::Meta::Role->initialize(caller);

    my $code = pop;
    for (@_) {
        $meta->add_around_method_modifier($_ => $code);
    }
}

sub has {
    my $meta = Mouse::Meta::Role->initialize(caller);

    my $name = shift;
    my %opts = @_;

    $meta->add_attribute($name => \%opts);
}

sub extends  { confess "Roles do not support 'extends'" }

sub with     { confess "Mouse::Role does not currently support 'with'" }

sub requires { confess "Mouse::Role does not currently support 'requires'" }

sub excludes { confess "Mouse::Role does not currently support 'excludes'" }

sub import {
    strict->import;
    warnings->import;

    my $caller = caller;
    my $meta = Mouse::Meta::Role->initialize(caller);

    no strict 'refs';
    no warnings 'redefine';
    *{$caller.'::meta'} = sub { $meta };

    Mouse::Role->export_to_level(1, @_);
}

sub unimport {
    my $caller = caller;

    no strict 'refs';
    for my $keyword (@EXPORT) {
        delete ${ $caller . '::' }{$keyword};
    }
}

1;

__END__

=head1 NAME

Mouse::Role

=head1 KEYWORDS

=head2 meta -> Mouse::Meta::Role

Returns this role's metaclass instance.

=head2 before (method|methods) => Code

Sets up a "before" method modifier. See L<Moose/before> or
L<Class::Method::Modifiers/before>.

=head2 after (method|methods) => Code

Sets up an "after" method modifier. See L<Moose/after> or
L<Class::Method::Modifiers/after>.

=head2 around (method|methods) => Code

Sets up an "around" method modifier. See L<Moose/around> or
L<Class::Method::Modifiers/around>.

=head2 has (name|names) => parameters

Sets up an attribute (or if passed an arrayref of names, multiple attributes) to
this role. See L<Mouse/has>.

=head2 confess error -> BOOM

L<Carp/confess> for your convenience.

=head2 blessed value -> ClassName | undef

L<Scalar::Util/blessed> for your convenience.

=head1 MISC

=head2 import

Importing Mouse::Role will give you sugar.

=head2 unimport

Please unimport Mouse (C<no Mouse::Role>) so that if someone calls one of the
keywords (such as L</has>) it will break loudly instead breaking subtly.

=cut

