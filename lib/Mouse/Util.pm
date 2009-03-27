package Mouse::Util;
use strict;
use warnings;
use base qw/Exporter/;
use Carp;

our @EXPORT_OK = qw(
    get_linear_isa
    apply_all_roles
    version 
    authority
    identifier
);
our %EXPORT_TAGS = (
    all  => \@EXPORT_OK,
);

BEGIN {
    my $impl;
    if ($] >= 5.009_005) {
        require mro;
        $impl = \&mro::get_linear_isa;
    } else {
        my $loaded = do {
            local $SIG{__DIE__} = 'DEFAULT';
            eval { require MRO::Compat; 1 };
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

{ # adapted from Class::MOP::Module

    sub version { no strict 'refs'; ${shift->name.'::VERSION'} }
    sub authority { no strict 'refs'; ${shift->name.'::AUTHORITY'} }  
    sub identifier {
        my $self = shift;
        join '-' => (
            $self->name,
            ($self->version   || ()),
            ($self->authority || ()),
        );
    }
}

# taken from Class/MOP.pm
{
    my %cache;

    sub resolve_metaclass_alias {
        my ( $type, $metaclass_name, %options ) = @_;

        my $cache_key = $type;
        return $cache{$cache_key}{$metaclass_name}
          if $cache{$cache_key}{$metaclass_name};

        my $possible_full_name =
            'Mouse::Meta::' 
          . $type
          . '::Custom::'
          . $metaclass_name;

        my $loaded_class =
          load_first_existing_class( $possible_full_name,
            $metaclass_name );

        return $cache{$cache_key}{$metaclass_name} =
            $loaded_class->can('register_implementation')
          ? $loaded_class->register_implementation
          : $loaded_class;
    }
}

# taken from Class/MOP.pm
sub _is_valid_class_name {
    my $class = shift;

    return 0 if ref($class);
    return 0 unless defined($class);
    return 0 unless length($class);

    return 1 if $class =~ /^\w+(?:::\w+)*$/;

    return 0;
}

# taken from Class/MOP.pm
sub load_first_existing_class {
    my @classes = @_
      or return;

    foreach my $class (@classes) {
        unless ( _is_valid_class_name($class) ) {
            my $display = defined($class) ? $class : 'undef';
            confess "Invalid class name ($display)";
        }
    }

    my $found;
    my %exceptions;
    for my $class (@classes) {
        my $e = _try_load_one_class($class);

        if ($e) {
            $exceptions{$class} = $e;
        }
        else {
            $found = $class;
            last;
        }
    }
    return $found if $found;

    confess join(
        "\n",
        map {
            sprintf( "Could not load class (%s) because : %s",
                $_, $exceptions{$_} )
          } @classes
    );
}

# taken from Class/MOP.pm
sub _try_load_one_class {
    my $class = shift;

    return if Mouse::is_class_loaded($class);

    my $file = $class . '.pm';
    $file =~ s{::}{/}g;

    return do {
        local $@;
        eval { require($file) };
        $@;
    };
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

