package Mouse::Util;
use strict;
use warnings;
use base qw/Exporter/;
use Carp;

our @EXPORT_OK = qw(
    get_linear_isa
);
our %EXPORT_TAGS = (
    all  => \@EXPORT_OK,
);

BEGIN {
    my $impl;
    if ($] >= 5.009_005) {
        $impl = \&mro::get_linear_isa;
    } else {
        my $loaded = do {
            local $SIG{__DIE__} = 'DEFAULT';
            eval "require MRO::Compat; 1";
        };
        if ($loaded) {
            $impl = \&mro::get_linear_isa;
        } else {
#       VVVVV   CODE TAKEN FROM MRO::COMPAT   VVVVV
            my $code; # this recurses so it isn't pretty
            $code = sub {
                no strict 'refs';

                my $classname = shift;

                my @lin = ($classname);
                my %stored;
                foreach my $parent (@{"$classname\::ISA"}) {
                    my $plin = $code->($parent);
                    foreach (@$plin) {
                        next if exists $stored{$_};
                        push(@lin, $_);
                        $stored{$_} = 1;
                    }
                }
                return \@lin;
            };
#       ^^^^^   CODE TAKEN FROM MRO::COMPAT   ^^^^^
            $impl = $code;
        }
    }

    no strict 'refs';
    *{ __PACKAGE__ . '::get_linear_isa'} = $impl;
}

sub apply_all_roles {
    my $meta = Mouse::Meta::Class->initialize(shift);

    my @roles;

    # Basis of Data::OptList
    my $max = scalar(@_);
    for (my $i = 0; $i < $max ; $i++) {
        if ($i + 1 < $max && ref($_[$i + 1])) {
            push @roles, [ $_[$i++] => $_[$i] ];
        } else {
            push @roles, [ $_[$i] => {} ];
        }
    }

    foreach my $role_spec (@roles) {
        Mouse::load_class( $role_spec->[0] );
    }

    ( $_->[0]->can('meta') && $_->[0]->meta->isa('Mouse::Meta::Role') )
        || croak("You can only consume roles, "
        . $_->[0]
        . " is not a Moose role")
        foreach @roles;

    if ( scalar @roles == 1 ) {
        my ( $role, $params ) = @{ $roles[0] };
        $role->meta->apply( $meta, ( defined $params ? %$params : () ) );
    }
    else {
        Mouse::Meta::Role->combine_apply($meta, @roles);
    }

}

1;

__END__

=head1 NAME

Mouse::Util - features, with or without their dependencies

=head1 IMPLEMENTATIONS FOR

=head2 L<MRO::Compat>

=head3 get_linear_isa

=cut

