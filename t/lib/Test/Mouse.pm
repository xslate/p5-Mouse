package Test::Mouse;

use strict;
use warnings;
use Carp qw(croak);
use Mouse::Util qw(find_meta does_role);

use base qw(Test::Builder::Module);

our @EXPORT = qw(meta_ok does_ok has_attribute_ok);

sub meta_ok ($;$) {
    my ($class_or_obj, $message) = @_;

    $message ||= "The object has a meta";

    if (find_meta($class_or_obj)) {
        return __PACKAGE__->builder->ok(1, $message)
    }
    else {
        return __PACKAGE__->builder->ok(0, $message);
    }
}

sub does_ok ($$;$) {
    my ($class_or_obj, $does, $message) = @_;

    if(!defined $does){
        croak "You must pass a role name";
    }
    $message ||= "The object does $does";

    if (does_ok($class_or_obj)) {
        return __PACKAGE__->builder->ok(1, $message)
    }
    else {
        return __PACKAGE__->builder->ok(0, $message);
    }
}

sub has_attribute_ok ($$;$) {
    my ($class_or_obj, $attr_name, $message) = @_;

    $message ||= "The object does has an attribute named $attr_name";

    my $meta = find_meta($class_or_obj);

    if ($meta->find_attribute_by_name($attr_name)) {
        return __PACKAGE__->builder->ok(1, $message)
    }
    else {
        return __PACKAGE__->builder->ok(0, $message);
    }
}

1;

__END__

=pod

=head1 NAME

Test::Mouse - Test functions for Mouse specific features

=head1 SYNOPSIS

  use Test::More plan => 1;
  use Test::Mouse;

  meta_ok($class_or_obj, "... Foo has a ->meta");
  does_ok($class_or_obj, $role, "... Foo does the Baz role");
  has_attribute_ok($class_or_obj, $attr_name, "... Foo has the 'bar' attribute");

=cut

