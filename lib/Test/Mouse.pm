package Test::Mouse;

use Mouse::Exporter;
use Mouse::Util qw(does_role find_meta);

use Test::Builder;

Mouse::Exporter->setup_import_methods(
    as_is => [qw(
        meta_ok
        does_ok
        has_attribute_ok
        with_immutable
    )],
);

## the test builder instance ...

my $Test = Test::Builder->new;

## exported functions

sub meta_ok ($;$) { ## no critic
    my ($class_or_obj, $message) = @_;

    $message ||= "The object has a meta";

    if (find_meta($class_or_obj)) {
        return $Test->ok(1, $message)
    }
    else {
        return $Test->ok(0, $message);
    }
}

sub does_ok ($$;$) { ## no critic
    my ($class_or_obj, $does, $message) = @_;

    $message ||= "The object does $does";

    if (does_role($class_or_obj, $does)) {
        return $Test->ok(1, $message)
    }
    else {
        return $Test->ok(0, $message);
    }
}

sub has_attribute_ok ($$;$) { ## no critic
    my ($class_or_obj, $attr_name, $message) = @_;

    $message ||= "The object does has an attribute named $attr_name";

    my $meta = find_meta($class_or_obj);

    if ($meta->find_attribute_by_name($attr_name)) {
        return $Test->ok(1, $message)
    }
    else {
        return $Test->ok(0, $message);
    }
}

sub with_immutable (&@) { ## no critic
    my $block = shift;

    my $before = $Test->current_test;

    $block->();
    $_->meta->make_immutable for @_;
    $block->();
    return if not defined wantarray;

    my $num_tests = $Test->current_test - $before;
    return !grep{ !$_ } ($Test->summary)[-$num_tests .. -1];
}

1;
__END__

=head1 NAME

Test::Mouse - Test functions for Mouse specific features

=head1 SYNOPSIS

  use Test::More plan => 1;
  use Test::Mouse;

  meta_ok($class_or_obj, "... Foo has a ->meta");
  does_ok($class_or_obj, $role, "... Foo does the Baz role");
  has_attribute_ok($class_or_obj, $attr_name, "... Foo has the 'bar' attribute");

=head1 DESCRIPTION

This module provides some useful test functions for Mouse based classes. It
is an experimental first release, so comments and suggestions are very welcome.

=head1 EXPORTED FUNCTIONS

=over 4

=item B<meta_ok ($class_or_object)>

Tests if a class or object has a metaclass.

=item B<does_ok ($class_or_object, $role, ?$message)>

Tests if a class or object does a certain role, similar to what C<isa_ok>
does for the C<isa> method.

=item B<has_attribute_ok($class_or_object, $attr_name, ?$message)>

Tests if a class or object has a certain attribute, similar to what C<can_ok>
does for the methods.

=item B<with_immutable { CODE } @class_names>

Runs I<CODE> *which should contain normal tests) twice, and make each
class in I<@class_names> immutable between the two runs.

=back

=head1 SEE ALSO

L<Mouse>

L<Test::Moose>

L<Test::More>

=cut

