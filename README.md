[![Build Status](https://travis-ci.org/gfx/p5-Mouse.png?branch=master)](https://travis-ci.org/gfx/p5-Mouse)
# NAME

Mouse - Moose minus the antlers

# VERSION

This document describes Mouse version 2.1.1

# SYNOPSIS

    package Point;
    use Mouse; # automatically turns on strict and warnings

    has 'x' => (is => 'rw', isa => 'Int');
    has 'y' => (is => 'rw', isa => 'Int');

    sub clear {
        my($self) = @_;
        $self->x(0);
        $self->y(0);
    }



    __PACKAGE__->meta->make_immutable();

    package Point3D;
    use Mouse;

    extends 'Point';

    has 'z' => (is => 'rw', isa => 'Int');

    after 'clear' => sub {
        my($self) = @_;
        $self->z(0);
    };

    __PACKAGE__->meta->make_immutable();

# DESCRIPTION

[Moose](http://search.cpan.org/perldoc?Moose) is a postmodern object system for Perl5. Moose is wonderful.

Unfortunately, Moose has a compile-time penalty. Though significant progress
has been made over the years, the compile time penalty is a non-starter for
some very specific applications. If you are writing a command-line application
or CGI script where startup time is essential, you may not be able to use
Moose (we recommend that you instead use persistent Perl executing environments
like `FastCGI` for the latter, if possible).

Mouse is a Moose compatible object system, which aims to alleviate this penalty
by providing a subset of Moose's functionality.

We're also going as light on dependencies as possible. Mouse currently has
__no dependencies__ except for building/testing modules. Mouse also works
without XS, although it has an XS backend to make it much faster.

## Moose Compatibility

Compatibility with Moose has been the utmost concern. The sugary interface is
highly compatible with Moose. Even the error messages are taken from Moose.
The Mouse code just runs its test suite 4x faster.

The idea is that, if you need the extra power, you should be able to run
`s/Mouse/Moose/g` on your codebase and have nothing break. To that end,
we have written [Any::Moose](http://search.cpan.org/perldoc?Any::Moose) which will act as Mouse unless Moose is loaded,
in which case it will act as Moose. Since Mouse is a little sloppier than
Moose, if you run into weird errors, it would be worth running:

    ANY_MOOSE=Moose perl your-script.pl

to see if the bug is caused by Mouse. Moose's diagnostics and validation are
also better.

See also [Mouse::Spec](http://search.cpan.org/perldoc?Mouse::Spec) for compatibility and incompatibility with Moose.

## Mouse Extentions

Please don't copy MooseX code to MouseX. If you need extensions, you really
should upgrade to Moose. We don't need two parallel sets of extensions!

If you really must write a Mouse extension, please contact the Moose mailing
list or \#moose on IRC beforehand.

# KEYWORDS

## `$object->meta -> Mouse::Meta::Class`

Returns this class' metaclass instance.

## `extends superclasses`

Sets this class' superclasses.

## `before (method|methods|regexp) => CodeRef`

Installs a "before" method modifier. See ["before" in Moose](http://search.cpan.org/perldoc?Moose#before).

## `after (method|methods|regexp) => CodeRef`

Installs an "after" method modifier. See ["after" in Moose](http://search.cpan.org/perldoc?Moose#after).

## `around (method|methods|regexp) => CodeRef`

Installs an "around" method modifier. See ["around" in Moose](http://search.cpan.org/perldoc?Moose#around).

## `has (name|names) => parameters`

Adds an attribute (or if passed an arrayref of names, multiple attributes) to
this class. Options:

- `is => ro|rw|bare`

    The _is_ option accepts either _rw_ (for read/write), _ro_ (for read
    only) or _bare_ (for nothing). These will create either a read/write accessor
    or a read-only accessor respectively, using the same name as the `$name` of
    the attribute.

    If you need more control over how your accessors are named, you can
    use the `reader`, `writer` and `accessor` options, however if you
    use those, you won't need the _is_ option.

- `isa => TypeName | ClassName`

    Provides type checking in the constructor and accessor. The following types are
    supported. Any unknown type is taken to be a class check
    (e.g. `isa => 'DateTime'` would accept only [DateTime](http://search.cpan.org/perldoc?DateTime) objects).

        Any Item Bool Undef Defined Value Num Int Str ClassName
        Ref ScalarRef ArrayRef HashRef CodeRef RegexpRef GlobRef
        FileHandle Object

    For more documentation on type constraints, see [Mouse::Util::TypeConstraints](http://search.cpan.org/perldoc?Mouse::Util::TypeConstraints).

- `does => RoleName`

    This will accept the name of a role which the value stored in this attribute
    is expected to have consumed.

- `coerce => Bool`

    This will attempt to use coercion with the supplied type constraint to change
    the value passed into any accessors or constructors. You __must__ have supplied
    a type constraint in order for this to work. See [Moose::Cookbook::Basics::Recipe5](http://search.cpan.org/perldoc?Moose::Cookbook::Basics::Recipe5)
    for an example.

- `required => Bool`

    Whether this attribute is required to have a value. If the attribute is lazy or
    has a builder, then providing a value for the attribute in the constructor is
    optional.

- `init_arg => Str | Undef`

    Allows you to use a different key name in the constructor.  If undef, the
    attribute can't be passed to the constructor.

- `default => Value | CodeRef`

    Sets the default value of the attribute. If the default is a coderef, it will
    be invoked to get the default value. Due to quirks of Perl, any bare reference
    is forbidden, you must wrap the reference in a coderef. Otherwise, all
    instances will share the same reference.

- `lazy => Bool`

    If specified, the default is calculated on demand instead of in the
    constructor.

- `predicate => Str`

    Lets you specify a method name for installing a predicate method, which checks
    that the attribute has a value. It will not invoke a lazy default or builder
    method.

- `clearer => Str`

    Lets you specify a method name for installing a clearer method, which clears
    the attribute's value from the instance. On the next read, lazy or builder will
    be invoked.

- `handles => HashRef|ArrayRef|Regexp`

    Lets you specify methods to delegate to the attribute. ArrayRef forwards the
    given method names to method calls on the attribute. HashRef maps local method
    names to remote method names called on the attribute. Other forms of
    ["handles"](#handles), such as RoleName and CodeRef, are not yet supported.

- `weak_ref => Bool`

    Lets you automatically weaken any reference stored in the attribute.

    Use of this feature requires [Scalar::Util](http://search.cpan.org/perldoc?Scalar::Util)!

- `trigger => CodeRef`

    Any time the attribute's value is set (either through the accessor or the constructor), the trigger is called on it. The trigger receives as arguments the instance, and the new value.

- `builder => Str`

    Defines a method name to be called to provide the default value of the
    attribute. `builder => 'build_foo'` is mostly equivalent to
    `default => sub { $_[0]->build_foo }`.

- `auto_deref => Bool`

    Allows you to automatically dereference ArrayRef and HashRef attributes in list
    context. In scalar context, the reference is returned (NOT the list length or
    bucket status). You must specify an appropriate type constraint to use
    auto\_deref.

- `lazy_build => Bool`

    Automatically define the following options:

        has $attr => (
            # ...
            lazy      => 1
            builder   => "_build_$attr",
            clearer   => "clear_$attr",
            predicate => "has_$attr",
        );

## `confess(message) -> BOOM`

["confess" in Carp](http://search.cpan.org/perldoc?Carp#confess) for your convenience.

## `blessed(value) -> ClassName | undef`

["blessed" in Scalar::Util](http://search.cpan.org/perldoc?Scalar::Util#blessed) for your convenience.

# MISC

## import

Importing Mouse will default your class' superclass list to [Mouse::Object](http://search.cpan.org/perldoc?Mouse::Object).
You may use ["extends"](#extends) to replace the superclass list.

## unimport

Please unimport Mouse (`no Mouse`) so that if someone calls one of the
keywords (such as ["extends"](#extends)) it will break loudly instead breaking subtly.

# SOURCE CODE ACCESS

We have a public git repository [https://github.com/gfx/p5-Mouse](https://github.com/gfx/p5-Mouse):.

    git clone git://github.com/gfx/p5-Mouse.git

# DEPENDENCIES

Perl 5.6.2 or later.

# SEE ALSO

[Mouse::Role](http://search.cpan.org/perldoc?Mouse::Role)

[Mouse::Spec](http://search.cpan.org/perldoc?Mouse::Spec)

[Moose](http://search.cpan.org/perldoc?Moose)

[Moose::Manual](http://search.cpan.org/perldoc?Moose::Manual)

[Moose::Cookbook](http://search.cpan.org/perldoc?Moose::Cookbook)

[Class::MOP](http://search.cpan.org/perldoc?Class::MOP)

[Moo](http://search.cpan.org/perldoc?Moo)

# AUTHORS

Shawn M Moore <sartak at gmail.com>

Yuval Kogman <nothingmuch at woobling.org>

tokuhirom

Yappo

wu-lee

Goro Fuji (gfx) <gfuji@cpan.org>

with plenty of code borrowed from [Class::MOP](http://search.cpan.org/perldoc?Class::MOP) and [Moose](http://search.cpan.org/perldoc?Moose)

# BUGS

All complex software has bugs lurking in it, and this module is no exception.
Please report any bugs to `bug-mouse at rt.cpan.org`, or through the web
interface at [http://rt.cpan.org/Public/Dist/Display.html?Name=Mouse](http://rt.cpan.org/Public/Dist/Display.html?Name=Mouse)

# COPYRIGHT AND LICENSE

Copyright (c) 2008-2010 Infinity Interactive, Inc.

http://www.iinteractive.com/

This program is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.
