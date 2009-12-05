package Mouse::Util::MetaRole;
use Mouse::Util; # enables strict and warnings

my @MetaClassTypes = qw(
    metaclass
    attribute_metaclass
    method_metaclass
    constructor_class
    destructor_class
);

# In Mouse::Exporter::do_import():
# apply_metaclass_roles(for_class => $class, metaclass_roles => \@traits)
sub apply_metaclass_roles {
    my %options = @_;

    my $for = Scalar::Util::blessed($options{for_class})
        ? $options{for_class}
        : Mouse::Util::get_metaclass_by_name($options{for_class});

    my $new_metaclass = _make_new_class( ref $for,
        $options{metaclass_roles},
        $options{metaclass} ? [$options{metaclass}] : undef,
    );

    my @metaclass_map;

    foreach my $mc_type(@MetaClassTypes){
        next if !$for->can($mc_type);

        if(my $roles = $options{ $mc_type . '_roles' }){
            push @metaclass_map,
                ($mc_type => _make_new_class($for->$mc_type(), $roles));
        }
        elsif(my $mc = $options{$mc_type}){
            push @metaclass_map, ($mc_type => $mc);
        }
    }

    return $new_metaclass->reinitialize( $for, @metaclass_map );
}

sub apply_base_class_roles {
    my %options = @_;

    my $for = $options{for_class};

    my $meta = Mouse::Util::class_of($for);

    my $new_base = _make_new_class(
        $for,
        $options{roles},
        [ $meta->superclasses() ],
    );

    $meta->superclasses($new_base)
        if $new_base ne $meta->name();
    return;
}

sub _make_new_class {
    my($existing_class, $roles, $superclasses) = @_;

    if(!$superclasses){
        return $existing_class if !$roles;

        my $meta = Mouse::Meta::Class->initialize($existing_class);

        return $existing_class
            if !grep { !ref($_) && !$meta->does_role($_) } @{$roles};
    }

    return Mouse::Meta::Class->create_anon_class(
        superclasses => $superclasses ? $superclasses : [$existing_class],
        roles        => $roles,
        cache        => 1,
    )->name();
}

1;
__END__

=head1 NAME

Mouse::Util::MetaRole - Apply roles to any metaclass, as well as the object base class

=head1 SYNOPSIS

  package MyApp::Mouse;

  use Mouse ();
  use Mouse::Exporter;
  use Mouse::Util::MetaRole;

  use MyApp::Role::Meta::Class;
  use MyApp::Role::Meta::Method::Constructor;
  use MyApp::Role::Object;

  Mouse::Exporter->setup_import_methods( also => 'Mouse' );

  sub init_meta {
      shift;
      my %options = @_;

      Mouse->init_meta(%options);

      Mouse::Util::MetaRole::apply_metaclass_roles(
          for_class               => $options{for_class},
          metaclass_roles         => ['MyApp::Role::Meta::Class'],
          constructor_class_roles => ['MyApp::Role::Meta::Method::Constructor'],
      );

      Mouse::Util::MetaRole::apply_base_class_roles(
          for_class => $options{for_class},
          roles     => ['MyApp::Role::Object'],
      );

      return $options{for_class}->meta();
  }

=head1 DESCRIPTION

This utility module is designed to help authors of Mouse extensions
write extensions that are able to cooperate with other Mouse
extensions. To do this, you must write your extensions as roles, which
can then be dynamically applied to the caller's metaclasses.

This module makes sure to preserve any existing superclasses and roles
already set for the meta objects, which means that any number of
extensions can apply roles in any order.

=head1 USAGE

B<It is very important that you only call this module's functions when
your module is imported by the caller>. The process of applying roles
to the metaclass reinitializes the metaclass object, which wipes out
any existing attributes already defined. However, as long as you do
this when your module is imported, the caller should not have any
attributes defined yet.

The easiest way to ensure that this happens is to use
L<Mouse::Exporter>, which can generate the appropriate C<init_meta>
method for you, and make sure it is called when imported.

=head1 FUNCTIONS

This module provides two functions.

=head2 apply_metaclass_roles( ... )

This function will apply roles to one or more metaclasses for the
specified class. It accepts the following parameters:

=over 4

=item * for_class => $name

This specifies the class for which to alter the meta classes.

=item * metaclass_roles => \@roles

=item * attribute_metaclass_roles => \@roles

=item * method_metaclass_roles => \@roles

=item * constructor_class_roles => \@roles

=item * destructor_class_roles => \@roles

These parameter all specify one or more roles to be applied to the
specified metaclass. You can pass any or all of these parameters at
once.

=back

=head2 apply_base_class_roles( for_class => $class, roles => \@roles )

This function will apply the specified roles to the object's base class.

=head1 SEE ALSO

L<Moose::Util::MetaRole>

=cut
