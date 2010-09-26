package MooseCompat;
# Moose compatible methods/functions

use Test::Builder (); # should load Test::Builder first

use Mouse ();
use Mouse::Util::MetaRole;
use Mouse::Meta::Method;
use Mouse::Meta::Role::Method;

$INC{'Mouse/Meta.pm'}          = __FILE__;
$INC{'Mouse/Meta/Instance.pm'} = __FILE__;
$INC{'Mouse/Deprecated.pm'}    = __FILE__;

*UNIVERSAL::DOES = sub {
    my($thing, $role) = @_;
    $thing->isa($role);
} unless UNIVERSAL->can('DOES');

$Mouse::Deprecated::deprecated = $Mouse::Deprecated::deprecated = undef; # -w

package Mouse::Util;

sub resolve_metatrait_alias {
    return resolve_metaclass_alias( @_, trait => 1);
}

sub ensure_all_roles {
    my $consumer = shift;
    apply_all_roles($consumer, grep { !does_role($appicant, $_) } @_);
    return;
}

package Mouse::Meta::Module;

sub version   { no strict 'refs'; ${shift->name.'::VERSION'}   }
sub authority { no strict 'refs'; ${shift->name.'::AUTHORITY'} }
sub identifier {
    my $self = shift;
    return join '-' => (
       $self->name,
        ($self->version   || ()),
        ($self->authority || ()),
    );
}

sub role_applications { }

package Mouse::Meta::Role;

for my $modifier_type (qw/before after around/) {
    my $modifier = "${modifier_type}_method_modifiers";
    my $has_method_modifiers = sub{
        my($self, $method_name) = @_;
        my $m = $self->{$modifier}->{$method_name};
        return $m && @{$m} != 0;
    };

    no strict 'refs';
    *{ 'has_' . $modifier_type . '_method_modifiers' } = $has_method_modifiers;
}


sub has_override_method_modifier {
    my ($self, $method_name) = @_;
    return exists $self->{override_method_modifiers}->{$method_name};
}

sub get_method_modifier_list {
    my($self, $modifier_type) = @_;

    return keys %{ $self->{$modifier_type . '_method_modifiers'} };
}

package Mouse::Meta::Method;

sub get_original_method { Mouse::Meta::Method->wrap(sub { }) }

sub associated_attribute { undef }

package Mouse::Util::TypeConstraints;

use Mouse::Util::TypeConstraints ();

sub export_type_constraints_as_functions { # TEST ONLY
    my $into = caller;

    foreach my $type( list_all_type_constraints() ) {
        my $tc = find_type_constraint($type)->_compiled_type_constraint;
        my $as = $into . '::' . $type;

        no strict 'refs';
        *{$as} = sub{ &{$tc} || undef };
    }
    return;
}

package Mouse::Meta::Attribute;

sub applied_traits{            $_[0]->{traits} } # TEST ONLY
sub has_applied_traits{ exists $_[0]->{traits} } # TEST ONLY

sub get_raw_value { undef } # not supported
sub set_raw_value { undef } # not supported

package Mouse::Meta::TypeConstraint;

sub has_message { exists $_[0]->{message} }

sub validate {
    my($self, $value) = @_;
    return $self->check($value) ? undef : $self->get_message($value);
}

sub is_subtype_of {
    my($self, $other) = @_;
    return undef; # not supported
}

sub equals {
    my($self, $other) = @_;
    return undef; # not supported
}

sub class { undef }
sub role  { undef }
1;
