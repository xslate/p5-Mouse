package ouse;
use Mouse::Util; # enables strict and warnings

my $package = 'Class';
sub import {
    $package = $_[1] || 'Class';
    if ($package =~ /^\+/) {
        $package =~ s/^\+//;
        Mouse::Util::load_class($package);
    }
}
use Filter::Simple sub { s/^/package $package;\nuse Mouse;\nuse Mouse::Util::TypeConstraints;\n/; };

1;
__END__

=head1 NAME

ouse - syntactic sugar to make Mouse one-liners easier

=head1 SYNOPSIS

  # create a Mouse class on the fly ...
  perl -Mouse=Foo -e 'has bar => ( is=>q[ro], default => q[baz] ); print Foo->new->bar' # prints baz

  # loads an existing class (Mouse or non-Mouse)
  # and re-"opens" the package definition to make
  # debugging/introspection easier
  perl -Mouse=+My::Class -e 'print join ", " => __PACKAGE__->meta->get_method_list'

=head1 DESCRIPTION

F<ouse.pm> is a simple source filter that adds C<package $name; use Mouse;>
to the beginning of your script and was entirely created because typing
perl C<< -e'package Foo; use Mouse; ...' >> was annoying me... especially after
getting used to having C<-Moose> for Moose.

=head1 INTERFACE

C<ouse> provides exactly one method and it is automatically called by perl:

=over 4

=item C<< oose->import() >>>

Pass a package name to import to be used by the source filter.

=back

=head1 DEPENDENCIES

You will need L<Filter::Simple> and eventually L<Mouse>

=head1 INCOMPATIBILITIES

None reported. But it is a source filter and might have issues there.

=head1 SEE ALSO

L<oose> for C<< perl -Moose -e '...' >>

=head1 AUTHOR

For all intents and purposes, blame:

Chris Prather  C<< <perigrin@cpan.org> >>

...who wrote oose.pm, which was adapted for use by Mouse by:

Ricardo SIGNES C<< <rjbs@cpan.org> >>

=head1 COPYRIGHT AND LICENSE

Copyright 2008 Shawn M Moore.

This program is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.

=cut
