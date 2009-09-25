package Mouse::Role;
use strict;
use warnings;

use Exporter;

use Carp 'confess';
use Scalar::Util 'blessed';

use Mouse::Util qw(load_class not_supported);
use Mouse ();

our @ISA = qw(Exporter);

our @EXPORT = qw(
    extends with
    has
    before after around
    override super
    augment  inner

    requires excludes

    blessed confess
);

our %is_removable = map{ $_ => undef } @EXPORT;
delete $is_removable{confess};
delete $is_removable{blessed};

sub before {
    my $meta = Mouse::Meta::Role->initialize(scalar caller);

    my $code = pop;
    for (@_) {
        $meta->add_before_method_modifier($_ => $code);
    }
}

sub after {
    my $meta = Mouse::Meta::Role->initialize(scalar caller);

    my $code = pop;
    for (@_) {
        $meta->add_after_method_modifier($_ => $code);
    }
}

sub around {
    my $meta = Mouse::Meta::Role->initialize(scalar caller);

    my $code = pop;
    for (@_) {
        $meta->add_around_method_modifier($_ => $code);
    }
}


sub super {
    return unless $Mouse::SUPER_BODY; 
    $Mouse::SUPER_BODY->(@Mouse::SUPER_ARGS);
}

sub override {
    my $classname = caller;
    my $meta = Mouse::Meta::Role->initialize($classname);

    my $name = shift;
    my $code = shift;
    my $fullname = "${classname}::${name}";

    defined &$fullname
        && $meta->throw_error("Cannot add an override of method '$fullname' "
                            . "because there is a local version of '$fullname'");

    $meta->add_override_method_modifier($name => sub {
        local $Mouse::SUPER_PACKAGE = shift;
        local $Mouse::SUPER_BODY = shift;
        local @Mouse::SUPER_ARGS = @_;

        $code->(@_);
    });
}

# We keep the same errors messages as Moose::Role emits, here.
sub inner {
    Carp::croak "Roles cannot support 'inner'";
}

sub augment {
    Carp::croak "Roles cannot support 'augment'";
}

sub has {
    my $meta = Mouse::Meta::Role->initialize(scalar caller);
    my $name = shift;

    $meta->add_attribute($_ => @_) for ref($name) ? @{$name} : $name;
}

sub extends  {
    Carp::croak "Roles do not support 'extends'"
}

sub with     {
    my $meta = Mouse::Meta::Role->initialize(scalar caller);
    Mouse::Util::apply_all_roles($meta->name, @_);
}

sub requires {
    my $meta = Mouse::Meta::Role->initialize(scalar caller);
    $meta->throw_error("Must specify at least one method") unless @_;
    $meta->add_required_methods(@_);
}

sub excludes {
    not_supported;
}

sub import {
    my $class = shift;

    strict->import;
    warnings->import;

    my $caller = caller;

    # we should never export to main
    if ($caller eq 'main') {
        warn qq{$class does not export its sugar to the 'main' package.\n};
        return;
    }

    Mouse::Meta::Role->initialize($caller)->add_method(meta => sub {
        return Mouse::Meta::Role->initialize(ref($_[0]) || $_[0]);
    });

    Mouse::Role->export_to_level(1, @_);
}

sub unimport {
    my $caller = caller;

    my $stash = do{
        no strict 'refs';
        \%{$caller . '::'}
    };

    for my $keyword (@EXPORT) {
        my $code;
        if(exists $is_removable{$keyword}
            && ($code = $caller->can($keyword))
            && (Mouse::Util::get_code_info($code))[0] eq __PACKAGE__){

            delete $stash->{$keyword};
        }
    }
    return;
}

1;

__END__

=head1 NAME

Mouse::Role - The Mouse Role

=head1 SYNOPSIS

    package MyRole;
    use Mouse::Role;

=head1 KEYWORDS

=head2 C<< meta -> Mouse::Meta::Role >>

Returns this role's metaclass instance.

=head2 C<< before (method|methods) -> CodeRef >>

Sets up a B<before> method modifier. See L<Moose/before> or
L<Class::Method::Modifiers/before>.

=head2 C<< after (method|methods) => CodeRef >>

Sets up an B<after> method modifier. See L<Moose/after> or
L<Class::Method::Modifiers/after>.

=head2 C<< around (method|methods) => CodeRef >>

Sets up an B<around> method modifier. See L<Moose/around> or
L<Class::Method::Modifiers/around>.

=head2 C<super>

Sets up the B<super> keyword. See L<Moose/super>.

=head2  C<< override method => CodeRef >>

Sets up an B<override> method modifier. See L<Moose/Role/override>.

=head2 C<inner>

This is not supported in roles and emits an error. See L<Moose/Role>.

=head2 C<< augment method => CodeRef >>

This is not supported in roles and emits an error. See L<Moose/Role>.

=head2 C<< has (name|names) => parameters >>

Sets up an attribute (or if passed an arrayref of names, multiple attributes) to
this role. See L<Mouse/has>.

=head2 C<< confess(error) -> BOOM >>

L<Carp/confess> for your convenience.

=head2 C<< blessed(value) -> ClassName | undef >>

L<Scalar::Util/blessed> for your convenience.

=head1 MISC

=head2 import

Importing Mouse::Role will give you sugar.

=head2 unimport

Please unimport (C<< no Mouse::Role >>) so that if someone calls one of the
keywords (such as L</has>) it will break loudly instead breaking subtly.

=head1 SEE ALSO

L<Moose::Role>

=cut

