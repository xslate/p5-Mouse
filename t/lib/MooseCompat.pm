package MooseCompat;
# Moose compatible methods/functions

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

package
    Mouse::Meta::Attribute;

sub applied_traits{            $_[0]->{traits} } # TEST ONLY
sub has_applied_traits{ exists $_[0]->{traits} } # TEST ONLY

1;
