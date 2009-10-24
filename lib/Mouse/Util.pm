package Mouse::Util;
use Mouse::Exporter; # enables strict and warnings

use Carp qw(confess);
use Scalar::Util qw(blessed);
use B ();

use constant _MOUSE_VERBOSE => !!$ENV{MOUSE_VERBOSE};

Mouse::Exporter->setup_import_methods(
    as_is => [qw(
        find_meta
        does_role
        resolve_metaclass_alias
        apply_all_roles
        english_list

        load_class
        is_class_loaded

        get_linear_isa
        get_code_info

        get_code_package

        not_supported

        does meta dump
        _MOUSE_VERBOSE
    )],
    groups => {
        default => [], # export no functions by default

        # The ':meta' group is 'use metaclass' for Mouse
        meta    => [qw(does meta dump _MOUSE_VERBOSE)],
    },
);

# aliases as public APIs
# it must be 'require', not 'use', because Mouse::Meta::Module depends on Mouse::Util
require Mouse::Meta::Module; # for the entities of metaclass cache utilities

BEGIN {
    *class_of                    = \&Mouse::Meta::Module::class_of;
    *get_metaclass_by_name       = \&Mouse::Meta::Module::get_metaclass_by_name;
    *get_all_metaclass_instances = \&Mouse::Meta::Module::get_all_metaclass_instances;
    *get_all_metaclass_names     = \&Mouse::Meta::Module::get_all_metaclass_names;
}

# Moose::Util compatible utilities

sub find_meta{
    return class_of( $_[0] );
}

sub does_role{
    my ($class_or_obj, $role_name) = @_;

    my $meta = class_of($class_or_obj);

    (defined $role_name)
        || ($meta || 'Mouse::Meta::Class')->throw_error("You must supply a role name to does()");

    return defined($meta) && $meta->does_role($role_name);
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

    sub get_code_package{
        my($coderef) = @_;

        my $cv = B::svref_2object($coderef);
        $cv->isa('B::CV') or return '';

        my $gv = $cv->GV;
        $gv->isa('B::GV') or return '';

        return $gv->STASH->NAME;
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

# Utilities from Class::MOP


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

    my %exceptions;
    for my $class (@classes) {
        my $e = _try_load_one_class($class);

        if ($e) {
            $exceptions{$class} = $e;
        }
        else {
            return $class;
        }
    }

    # not found
    confess join(
        "\n",
        map {
            sprintf( "Could not load class (%s) because : %s",
                $_, $exceptions{$_} )
          } @classes
    );
}

# taken from Class/MOP.pm
my %is_class_loaded_cache;
sub _try_load_one_class {
    my $class = shift;

    unless ( is_valid_class_name($class) ) {
        my $display = defined($class) ? $class : 'undef';
        confess "Invalid class name ($display)";
    }

    return undef if $is_class_loaded_cache{$class} ||= is_class_loaded($class);

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


sub apply_all_roles {
    my $applicant = blessed($_[0]) ? shift : Mouse::Meta::Class->initialize(shift);

    my @roles;

    # Basis of Data::OptList
    my $max = scalar(@_);
    for (my $i = 0; $i < $max ; $i++) {
        if ($i + 1 < $max && ref($_[$i + 1])) {
            push @roles, [ $_[$i] => $_[++$i] ];
        } else {
            push @roles, [ $_[$i] => undef ];
        }
        my $role_name = $roles[-1][0];
        load_class($role_name);

        my $metarole = get_metaclass_by_name($role_name);
        ( $metarole && $metarole->isa('Mouse::Meta::Role') )
            || $applicant->meta->throw_error("You can only consume roles, $role_name(".$role_name->meta.") is not a Mouse role");
    }

    if ( scalar @roles == 1 ) {
        my ( $role_name, $params ) = @{ $roles[0] };
        get_metaclass_by_name($role_name)->apply( $applicant, defined $params ? $params : () );
    }
    else {
        Mouse::Meta::Role->combine(@roles)->apply($applicant);
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


# common utilities

sub not_supported{
    my($feature) = @_;

    $feature ||= ( caller(1) )[3]; # subroutine name

    local $Carp::CarpLevel = $Carp::CarpLevel + 1;
    Carp::confess("Mouse does not currently support $feature");
}

# general meta() method
sub meta :method{
    return Mouse::Meta::Class->initialize(ref($_[0]) || $_[0]);
}

# general dump() method
sub dump :method {
    my($self, $maxdepth) = @_;

    require 'Data/Dumper.pm'; # we don't want to create its namespace
    my $dd = Data::Dumper->new([$self]);
    $dd->Maxdepth(defined($maxdepth) ? $maxdepth : 2);
    $dd->Indent(1);
    return $dd->Dump();
}

# general does() method
sub does :method;
*does = \&does_role; # alias

1;

__END__

=head1 NAME

Mouse::Util - Features, with or without their dependencies

=head1 VERSION

This document describes Mouse version 0.40

=head1 IMPLEMENTATIONS FOR

=head2 Moose::Util

=head3 C<find_meta>

=head3 C<does_role>

=head3 C<resolve_metaclass_alias>

=head3 C<apply_all_roles>

=head3 C<english_list>

=head2 Class::MOP

=head3 C<< is_class_loaded(ClassName) -> Bool >>

Returns whether C<ClassName> is actually loaded or not. It uses a heuristic which
involves checking for the existence of C<$VERSION>, C<@ISA>, and any
locally-defined method.

=head3 C<< load_class(ClassName) >>

This will load a given C<ClassName> (or die if it is not loadable).
This function can be used in place of tricks like
C<eval "use $module"> or using C<require>.

=head3 C<< Mouse::Util::class_of(ClassName or Object) >>

=head3 C<< Mouse::Util::get_metaclass_by_name(ClassName) >>

=head3 C<< Mouse::Util::get_all_metaclass_instances() >>

=head3 C<< Mouse::Util::get_all_metaclass_names() >>

=head2 MRO::Compat

=head3 C<get_linear_isa>

=head2 Sub::Identify

=head3 C<get_code_info>

=head1 UTILITIES FOR MOUSE

=head3 C<not_supported>

=head1 SEE ALSO

L<Moose::Util>

L<Class::MOP>

L<Sub::Identify>

L<MRO::Compat>

=cut

