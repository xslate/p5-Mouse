package Mouse;
use strict;
use warnings;
use 5.006;
use base 'Exporter';

our $VERSION = '0.22';

use Carp 'confess';
use Scalar::Util 'blessed';
use Mouse::Util;

use Mouse::Meta::Attribute;
use Mouse::Meta::Class;
use Mouse::Object;
use Mouse::Util::TypeConstraints;

our @EXPORT = qw(extends has before after around override super blessed confess with);

sub extends { Mouse::Meta::Class->initialize(caller)->superclasses(@_) }

sub has {
    my $meta = Mouse::Meta::Class->initialize(caller);
    $meta->add_attribute(@_);
}

sub before {
    my $meta = Mouse::Meta::Class->initialize(caller);

    my $code = pop;

    for (@_) {
        $meta->add_before_method_modifier($_ => $code);
    }
}

sub after {
    my $meta = Mouse::Meta::Class->initialize(caller);

    my $code = pop;

    for (@_) {
        $meta->add_after_method_modifier($_ => $code);
    }
}

sub around {
    my $meta = Mouse::Meta::Class->initialize(caller);

    my $code = pop;

    for (@_) {
        $meta->add_around_method_modifier($_ => $code);
    }
}

sub with {
    Mouse::Util::apply_all_roles((caller)[0], @_);
}

our $SUPER_PACKAGE;
our $SUPER_BODY;
our @SUPER_ARGS;

sub super {
    # This check avoids a recursion loop - see
    # t/100_bugs/020_super_recursion.t
    return if defined $SUPER_PACKAGE && $SUPER_PACKAGE ne caller();
    return unless $SUPER_BODY; $SUPER_BODY->(@SUPER_ARGS);
}

sub override {
    my $meta = Mouse::Meta::Class->initialize(caller);
    my $pkg = $meta->name;

    my $name = shift;
    my $code = shift;

    my $body = $pkg->can($name)
        or confess "You cannot override '$name' because it has no super method";

    $meta->add_method($name => sub {
        local $SUPER_PACKAGE = $pkg;
        local @SUPER_ARGS = @_;
        local $SUPER_BODY = $body;

        $code->(@_);
    });
}

sub import {
    my $class = shift;

    strict->import;
    warnings->import;

    my $opts = do {
        if (ref($_[0]) && ref($_[0]) eq 'HASH') {
            shift @_;
        } else {
            +{ };
        }
    };
    my $level = delete $opts->{into_level};
       $level = 0 unless defined $level;
    my $caller = caller($level);

    # we should never export to main
    if ($caller eq 'main') {
        warn qq{$class does not export its sugar to the 'main' package.\n};
        return;
    }

    my $meta = Mouse::Meta::Class->initialize($caller);
    $meta->superclasses('Mouse::Object')
        unless $meta->superclasses;

    # make a subtype for each Mouse class
    class_type($caller) unless find_type_constraint($caller);

    no strict 'refs';
    no warnings 'redefine';
    *{$caller.'::meta'} = sub { $meta };

    if (@_) {
        __PACKAGE__->export_to_level( $level+1, $class, @_);
    } else {
        # shortcut for the common case of no type character
        no strict 'refs';
        for my $keyword (@EXPORT) {
            *{ $caller . '::' . $keyword } = *{__PACKAGE__ . '::' . $keyword};
        }
    }
}

sub unimport {
    my $caller = caller;

    no strict 'refs';
    for my $keyword (@EXPORT) {
        delete ${ $caller . '::' }{$keyword};
    }
}

sub load_class {
    my $class = shift;

    if (ref($class) || !defined($class) || !length($class)) {
        my $display = defined($class) ? $class : 'undef';
        confess "Invalid class name ($display)";
    }

    return 1 if $class eq 'Mouse::Object';
    return 1 if is_class_loaded($class);

    (my $file = "$class.pm") =~ s{::}{/}g;

    eval { CORE::require($file) };
    confess "Could not load class ($class) because : $@" if $@;

    return 1;
}

sub is_class_loaded {
    my $class = shift;

    return 0 if ref($class) || !defined($class) || !length($class);

    # walk the symbol table tree to avoid autovififying
    # \*{${main::}{"Foo::"}} == \*main::Foo::

    my $pack = \*::;
    foreach my $part (split('::', $class)) {
        return 0 unless exists ${$$pack}{"${part}::"};
        $pack = \*{${$$pack}{"${part}::"}};
    }

    # check for $VERSION or @ISA
    return 1 if exists ${$$pack}{VERSION}
             && defined *{${$$pack}{VERSION}}{SCALAR};
    return 1 if exists ${$$pack}{ISA}
             && defined *{${$$pack}{ISA}}{ARRAY};

    # check for any method
    foreach ( keys %{$$pack} ) {
        next if substr($_, -2, 2) eq '::';
        return 1 if defined *{${$$pack}{$_}}{CODE};
    }

    # fail
    return 0;
}

1;

__END__

=head1 NAME

Mouse - Moose minus the antlers

=head1 SYNOPSIS

    package Point;
    use Mouse; # automatically turns on strict and warnings

    has 'x' => (is => 'rw', isa => 'Int');
    has 'y' => (is => 'rw', isa => 'Int');

    sub clear {
        my $self = shift;
        $self->x(0);
        $self->y(0);
    }

    package Point3D;
    use Mouse;

    extends 'Point';

    has 'z' => (is => 'rw', isa => 'Int');

    after 'clear' => sub {
        my $self = shift;
        $self->z(0);
    };

=head1 DESCRIPTION

L<Moose> is wonderful. B<Use Moose instead of Mouse.>

Unfortunately, Moose has a compile-time penalty. Though significant progress has
been made over the years, the compile time penalty is a non-starter for some
applications.

Mouse aims to alleviate this by providing a subset of Moose's functionality,
faster.

We're also going as light on dependencies as possible.
L<Class::Method::Modifiers> or L<Data::Util> is required if you want support
for L</before>, L</after>, and L</around>.

=head2 MOOSE COMPAT

Compatibility with Moose has been the utmost concern. Fewer than 1% of the
tests fail when run against Moose instead of Mouse. Mouse code coverage is also
over 96%. Even the error messages are taken from Moose. The Mouse code just
runs the test suite 4x faster.

The idea is that, if you need the extra power, you should be able to run
C<s/Mouse/Moose/g> on your codebase and have nothing break. To that end,
we have written L<Any::Moose> which will act as Mouse unless Moose is loaded,
in which case it will act as Moose.

=head2 MouseX

Please don't copy MooseX code to MouseX. If you need extensions, you really
should upgrade to Moose. We don't need two parallel sets of extensions!

If you really must write a Mouse extension, please contact the Moose mailing
list or #moose on IRC beforehand.

=head1 KEYWORDS

=head2 meta -> Mouse::Meta::Class

Returns this class' metaclass instance.

=head2 extends superclasses

Sets this class' superclasses.

=head2 before (method|methods) => Code

Installs a "before" method modifier. See L<Moose/before> or
L<Class::Method::Modifiers/before>.

Use of this feature requires L<Class::Method::Modifiers>!

=head2 after (method|methods) => Code

Installs an "after" method modifier. See L<Moose/after> or
L<Class::Method::Modifiers/after>.

Use of this feature requires L<Class::Method::Modifiers>!

=head2 around (method|methods) => Code

Installs an "around" method modifier. See L<Moose/around> or
L<Class::Method::Modifiers/around>.

Use of this feature requires L<Class::Method::Modifiers>!

=head2 has (name|names) => parameters

Adds an attribute (or if passed an arrayref of names, multiple attributes) to
this class. Options:

=over 4

=item is => ro|rw

If specified, inlines a read-only/read-write accessor with the same name as
the attribute.

=item isa => TypeConstraint

Provides type checking in the constructor and accessor. The following types are
supported. Any unknown type is taken to be a class check (e.g. isa =>
'DateTime' would accept only L<DateTime> objects).

    Any Item Bool Undef Defined Value Num Int Str ClassName
    Ref ScalarRef ArrayRef HashRef CodeRef RegexpRef GlobRef
    FileHandle Object

For more documentation on type constraints, see L<Mouse::Util::TypeConstraints>.


=item required => 0|1

Whether this attribute is required to have a value. If the attribute is lazy or
has a builder, then providing a value for the attribute in the constructor is
optional.

=item init_arg => Str | Undef

Allows you to use a different key name in the constructor.  If undef, the
attribue can't be passed to the constructor.

=item default => Value | CodeRef

Sets the default value of the attribute. If the default is a coderef, it will
be invoked to get the default value. Due to quirks of Perl, any bare reference
is forbidden, you must wrap the reference in a coderef. Otherwise, all
instances will share the same reference.

=item lazy => 0|1

If specified, the default is calculated on demand instead of in the
constructor.

=item predicate => Str

Lets you specify a method name for installing a predicate method, which checks
that the attribute has a value. It will not invoke a lazy default or builder
method.

=item clearer => Str

Lets you specify a method name for installing a clearer method, which clears
the attribute's value from the instance. On the next read, lazy or builder will
be invoked.

=item handles => HashRef|ArrayRef

Lets you specify methods to delegate to the attribute. ArrayRef forwards the
given method names to method calls on the attribute. HashRef maps local method
names to remote method names called on the attribute. Other forms of
L</handles>, such as regular expression and coderef, are not yet supported.

=item weak_ref => 0|1

Lets you automatically weaken any reference stored in the attribute.

Use of this feature requires L<Scalar::Util>!

=item trigger => CodeRef

Any time the attribute's value is set (either through the accessor or the constructor), the trigger is called on it. The trigger receives as arguments the instance, the new value, and the attribute instance.

Mouse 0.05 supported more complex triggers, but this behavior is now removed.

=item builder => Str

Defines a method name to be called to provide the default value of the
attribute. C<< builder => 'build_foo' >> is mostly equivalent to
C<< default => sub { $_[0]->build_foo } >>.

=item auto_deref => 0|1

Allows you to automatically dereference ArrayRef and HashRef attributes in list
context. In scalar context, the reference is returned (NOT the list length or
bucket status). You must specify an appropriate type constraint to use
auto_deref.

=item lazy_build => 0|1

Automatically define lazy => 1 as well as builder => "_build_$attr", clearer =>
"clear_$attr', predicate => 'has_$attr' unless they are already defined.

=back

=head2 confess error -> BOOM

L<Carp/confess> for your convenience.

=head2 blessed value -> ClassName | undef

L<Scalar::Util/blessed> for your convenience.

=head1 MISC

=head2 import

Importing Mouse will default your class' superclass list to L<Mouse::Object>.
You may use L</extends> to replace the superclass list.

=head2 unimport

Please unimport Mouse (C<no Mouse>) so that if someone calls one of the
keywords (such as L</extends>) it will break loudly instead breaking subtly.

=head1 FUNCTIONS

=head2 load_class Class::Name

This will load a given C<Class::Name> (or die if it's not loadable).
This function can be used in place of tricks like
C<eval "use $module"> or using C<require>.

=head2 is_class_loaded Class::Name -> Bool

Returns whether this class is actually loaded or not. It uses a heuristic which
involves checking for the existence of C<$VERSION>, C<@ISA>, and any
locally-defined method.

=head1 SOURCE CODE ACCESS

We have a public git repo:

 git clone git://jules.scsys.co.uk/gitmo/Mouse.git

=head1 AUTHORS

Shawn M Moore, C<< <sartak at gmail.com> >>

Yuval Kogman, C<< <nothingmuch at woobling.org> >>

tokuhirom

Yappo

wu-lee

with plenty of code borrowed from L<Class::MOP> and L<Moose>

=head1 BUGS

No known bugs.

Please report any bugs through RT: email
C<bug-mouse at rt.cpan.org>, or browse
L<http://rt.cpan.org/NoAuth/ReportBug.html?Queue=Mouse>.

=head1 COPYRIGHT AND LICENSE

Copyright 2008 Shawn M Moore.

This program is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.

=cut

