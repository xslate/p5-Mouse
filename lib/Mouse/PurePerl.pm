package
    Mouse::Util;

use strict;
use warnings;

use warnings FATAL => 'redefine'; # to avoid to load Mouse::PurePerl

use B ();

sub is_class_loaded {
    my $class = shift;

    return 0 if ref($class) || !defined($class) || !length($class);

    # walk the symbol table tree to avoid autovififying
    # \*{${main::}{"Foo::"}} == \*main::Foo::

    my $pack = \%::;
    foreach my $part (split('::', $class)) {
        my $entry = \$pack->{$part . '::'};
        return 0 if ref($entry) ne 'GLOB';
        $pack = *{$entry}{HASH} or return 0;
    }

    # check for $VERSION or @ISA
    return 1 if exists $pack->{VERSION}
             && defined *{$pack->{VERSION}}{SCALAR} && defined ${ $pack->{VERSION} };
    return 1 if exists $pack->{ISA}
             && defined *{$pack->{ISA}}{ARRAY} && @{ $pack->{ISA} } != 0;

    # check for any method
    foreach my $name( keys %{$pack} ) {
        my $entry = \$pack->{$name};
        return 1 if ref($entry) ne 'GLOB' || defined *{$entry}{CODE};
    }

    # fail
    return 0;
}


# taken from Sub::Identify
sub get_code_info {
    my ($coderef) = @_;
    ref($coderef) or return;

    my $cv = B::svref_2object($coderef);
    $cv->isa('B::CV') or return;

    my $gv = $cv->GV;
    $gv->isa('B::GV') or return;

    return ($gv->STASH->NAME, $gv->NAME);
}

sub get_code_package{
    my($coderef) = @_;

    my $cv = B::svref_2object($coderef);
    $cv->isa('B::CV') or return '';

    my $gv = $cv->GV;
    $gv->isa('B::GV') or return '';

    return $gv->STASH->NAME;
}


package
    Mouse::Meta::Method::Accessor;

1;
__END__
