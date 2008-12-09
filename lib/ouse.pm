package ouse;

use strict;
use warnings;

BEGIN {
    my $package;
    sub import { 
        $package = $_[1] || 'Class';
        if ($package =~ /^\+/) {
            $package =~ s/^\+//;
            eval "require $package; 1" or die;
        }
    }
    use Filter::Simple sub { s/^/package $package;\nuse Mouse;\n/; }
}

1;

__END__

=pod

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

ouse.pm is a simple source filter that adds C<package $name; use Mouse;> 
to the beginning of your script and was entirely created because typing 
perl -e'package Foo; use Mouse; ...' was annoying me... especially after
getting used to having C<-Moose> for Moose.

=head1 INTERFACE 

ouse provides exactly one method and it's automically called by perl:

=over 4

=item B<import($package)>

Pass a package name to import to be used by the source filter.

=back

=head1 DEPENDENCIES

You will need L<Filter::Simple> and eventually L<Mouse>

=head1 INCOMPATIBILITIES

None reported. But it is a source filter and might have issues there.

=head1 BUGS

All complex software has bugs lurking in it, and this module is no
exception. If you find a bug please either email me, or add the bug
to cpan-RT.

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
