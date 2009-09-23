package Mouse::Util;
use strict;
use warnings;
use base qw/Exporter/;

use Carp qw(confess);
use B ();

our @EXPORT_OK = qw(
    find_meta
    does_role
    resolve_metaclass_alias
    english_list

    load_class
    is_class_loaded

    apply_all_roles
    not_supported

    get_linear_isa
    get_code_info
);
our %EXPORT_TAGS = (
    all  => \@EXPORT_OK,
);

# Moose::Util compatible utilities

sub find_meta{
    return Mouse::Meta::Module::class_of( $_[0] );
}

sub does_role{
    my ($class_or_obj, $role) = @_;

    my $meta = Mouse::Meta::Module::class_of($class_or_obj);

    return 0 unless defined $meta;
    return 1 if $meta->does_role($role);
    return 0;
}



BEGIN {
    my $impl;
    if ($] >= 5.009_005) {
        require mro;
        $impl = \&mro::get_linear_isa;
    } else {
        my $e = do {
            local $@;
            eval { require MRO::Compat };
            $@;
        };
        if (!$e) {
            $impl = \&mro::get_linear_isa;
        } else {
#       VVVVV   CODE TAKEN FROM MRO::COMPAT   VVVVV
            my $_get_linear_isa_dfs; # this recurses so it isn't pretty
            $_get_linear_isa_dfs = sub {
                no strict 'refs';

                my $classname = shift;

                my @lin = ($classname);
                my %stored;
                foreach my $parent (@{"$classname\::ISA"}) {
                    my $plin = $_get_linear_isa_dfs->($parent);
                    foreach  my $p(@$plin) {
                        next if exists $stored{$p};
                        push(@lin, $p);
                        $stored{$p} = 1;
                    }
                }
                return \@lin;
            };
#       ^^^^^   CODE TAKEN FROM MRO::COMPAT   ^^^^^
            $impl = $_get_linear_isa_dfs;
        }
    }


    no warnings 'once';
    *get_linear_isa = $impl;
}

{ # taken from Sub::Identify
    sub get_code_info($) {
        my ($coderef) = @_;
        ref($coderef) or return;

        my $cv = B::svref_2object($coderef);
        $cv->isa('B::CV') or return;

        my $gv = $cv->GV;
        $gv->isa('B::GV') or return;

        return ($gv->STASH->NAME, $gv->NAME);
    }
}

# taken from Mouse::Util (0.90)
{
    my %cache;

    sub resolve_metaclass_alias {
        my ( $type, $metaclass_name, %options ) = @_;

        my $cache_key = $type . q{ } . ( $options{trait} ? '-Trait' : '' );

        return $cache{$cache_key}{$metaclass_name} ||= do{

            my $possible_full_name = join '::',
                'Mouse::Meta', $type, 'Custom', ($options{trait} ? 'Trait' : ()), $metaclass_name
            ;

            my $loaded_class = load_first_existing_class(
                $possible_full_name,
                $metaclass_name
            );

            $loaded_class->can('register_implementation')
                ? $loaded_class->register_implementation
                : $loaded_class;
        };
    }
}

# taken from Class/MOP.pm
sub is_valid_class_name {
    my $class = shift;

    return 0 if ref($class);
    return 0 unless defined($class);

    return 1 if $class =~ /^\w+(?:::\w+)*$/;

    return 0;
}

# taken from Class/MOP.pm
sub load_first_existing_class {
    my @classes = @_
      or return;

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

    unless ( is_valid_class_name($class) ) {
        my $display = defined($class) ? $class : 'undef';
        confess "Invalid class name ($display)";
    }

    return if is_class_loaded($class);

    my $file = $class . '.pm';
    $file =~ s{::}{/}g;

    return do {
        local $@;
        eval { require($file) };
        $@;
    };
}


sub load_class {
    my $class = shift;
    my $e = _try_load_one_class($class);
    confess "Could not load class ($class) because : $e" if $e;

    return 1;
}

my %is_class_loaded_cache;
sub is_class_loaded {
    my $class = shift;

    return 0 if ref($class) || !defined($class) || !length($class);

    return 1 if $is_class_loaded_cache{$class};

    # walk the symbol table tree to avoid autovififying
    # \*{${main::}{"Foo::"}} == \*main::Foo::

    my $pack = \%::;
    foreach my $part (split('::', $class)) {
        my $entry = \$pack->{$part . '::'};
        return 0 if ref($entry) ne 'GLOB';
        $pack = *{$entry}{HASH} or return 0;
    }

    # check for $VERSION or @ISA
    return ++$is_class_loaded_cache{$class} if exists $pack->{VERSION}
             && defined *{$pack->{VERSION}}{SCALAR} && defined ${ $pack->{VERSION} };
    return ++$is_class_loaded_cache{$class} if exists $pack->{ISA}
             && defined *{$pack->{ISA}}{ARRAY} && @{ $pack->{ISA} } != 0;

    # check for any method
    foreach my $name( keys %{$pack} ) {
        my $entry = \$pack->{$name};
        return ++$is_class_loaded_cache{$class} if ref($entry) ne 'GLOB' || defined *{$entry}{CODE};
    }

    # fail
    return 0;
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
        my $role_name = $roles[-1][0];
        load_class($role_name);
        ( $role_name->can('meta') && $role_name->meta->isa('Mouse::Meta::Role') )
            || $meta->throw_error("You can only consume roles, $role_name(".$role_name->meta.") is not a Mouse role");
    }

    if ( scalar @roles == 1 ) {
        my ( $role, $params ) = @{ $roles[0] };
        $role->meta->apply( $meta, ( defined $params ? %$params : () ) );
    }
    else {
        Mouse::Meta::Role->combine_apply($meta, @roles);
    }
    return;
}

# taken from Moose::Util 0.90
sub english_list {
    return $_[0] if @_ == 1;

    my @items = sort @_;

    return "$items[0] and $items[1]" if @items == 2;

    my $tail = pop @items;

    return join q{, }, @items, "and $tail";
}

sub not_supported{
    my($feature) = @_;

    $feature ||= ( caller(1) )[3]; # subroutine name

    local $Carp::CarpLevel = $Carp::CarpLevel + 2;
    Carp::croak("Mouse does not currently support $feature");
}

1;

__END__

=head1 NAME

Mouse::Util - features, with or without their dependencies

=head1 IMPLEMENTATIONS FOR

=head2 L<MRO::Compat>

=head3 get_linear_isa

=cut

