#!/usr/bin/env perl
use strict;
use warnings;
use Test::More tests => 7;
use lib 't/lib';

do {
    # copied from  MooseX::AttributeHelpers;
    package MouseX::AttributeHelpers::Trait::Base;
    use Mouse::Role;
    use Mouse::Util::TypeConstraints;

    requires 'helper_type';

    # this is the method map you define ...
    has 'provides' => (
        is      => 'ro',
        isa     => 'HashRef',
        default => sub {{}}
    );

    has 'curries' => (
        is      => 'ro',
        isa     => 'HashRef',
        default => sub {{}}
    );

    # these next two are the possible methods
    # you can use in the 'provides' map.

    # provide a Class or Role which we can
    # collect the method providers from

    # requires_attr 'method_provider'

    # or you can provide a HASH ref of anon subs
    # yourself. This will also collect and store
    # the methods from a method_provider as well
    has 'method_constructors' => (
        is      => 'ro',
        isa     => 'HashRef',
        lazy    => 1,
        default => sub {
            my $self = shift;
            return +{} unless $self->has_method_provider;
            # or grab them from the role/class
            my $method_provider = $self->method_provider->meta;
            return +{
                map {
                    $_ => $method_provider->get_method($_)
                }
                grep { $_ ne 'meta' } $method_provider->get_method_list
            };
        },
    );

    # extend the parents stuff to make sure
    # certain bits are now required ...
    #has 'default'         => (required => 1);
    has 'type_constraint' => (is => 'rw', required => 1);

    ## Methods called prior to instantiation

    sub process_options_for_provides {
        my ($self, $options) = @_;

        if (my $type = $self->helper_type) {
            (exists $options->{isa})
                || confess "You must define a type with the $type metaclass";

            my $isa = $options->{isa};

            unless (blessed($isa) && $isa->isa('Mouse::Meta::TypeConstraint')) {
                $isa = Mouse::Util::TypeConstraints::find_or_create_isa_type_constraint($isa);
            }

            #($isa->is_a_type_of($type))
            #    || confess "The type constraint for a $type ($options->{isa}) must be a subtype of $type";
        }
    }

    before '_process_options' => sub {
        my ($self, $name, $options) = @_;
        $self->process_options_for_provides($options, $name);
    };

    ## methods called after instantiation

    sub check_provides_values {
        my $self = shift;

        my $method_constructors = $self->method_constructors;

        foreach my $key (keys %{$self->provides}) {
            (exists $method_constructors->{$key})
                || confess "$key is an unsupported method type";
        }

        foreach my $key (keys %{$self->curries}) {
            (exists $method_constructors->{$key})
                || confess "$key is an unsupported method type";
        }
    }

    sub _curry {
        my $self = shift;
        my $code = shift;

        my @args = @_;
        return sub {
            my $self = shift;
            $code->($self, @args, @_)
        };
    }

    sub _curry_sub {
        my $self = shift;
        my $body = shift;
        my $code = shift;

        return sub {
            my $self = shift;
            $code->($self, $body, @_)
        };
    }

    after 'install_accessors' => sub {
        my $attr  = shift;
        my $class = $attr->associated_class;

        # grab the reader and writer methods
        # as well, this will be useful for
        # our method provider constructors
        my $attr_reader = $attr->get_read_method_ref;
        my $attr_writer = $attr->get_write_method_ref;


        # before we install them, lets
        # make sure they are valid
        $attr->check_provides_values;

        my $method_constructors = $attr->method_constructors;

        my $class_name = $class->name;

        while (my ($constructor, $constructed) = each %{$attr->curries}) {
            my $method_code;
            while (my ($curried_name, $curried_arg) = each(%$constructed)) {
                if ($class->has_method($curried_name)) {
                    confess
                        "The method ($curried_name) already ".
                        "exists in class (" . $class->name . ")";
                }
                my $body = $method_constructors->{$constructor}->(
                           $attr,
                           $attr_reader,
                           $attr_writer,
                );

                if (ref $curried_arg eq 'ARRAY') {
                    $method_code = $attr->_curry($body, @$curried_arg);
                }
                elsif (ref $curried_arg eq 'CODE') {
                    $method_code = $attr->_curry_sub($body, $curried_arg);
                }
                else {
                    confess "curries parameter must be ref type ARRAY or CODE";
                }

                my $method = MouseX::AttributeHelpers::Meta::Method::Curried->wrap(
                    $method_code,
                    package_name => $class_name,
                    name => $curried_name,
                );

                $attr->associate_method($method);
                $class->add_method($curried_name => $method);
            }
        }

        foreach my $key (keys %{$attr->provides}) {

            my $method_name = $attr->provides->{$key};

            if ($class->has_method($method_name)) {
                confess "The method ($method_name) already exists in class (" . $class->name . ")";
            }

            my $method = $method_constructors->{$key}->(
                $attr,
                $attr_reader,
                $attr_writer,
            );

            $class->add_method($method_name => $method);
        }
    };

    package MouseX::AttributeHelpers::Trait::Number;
    use Mouse::Role;

    with 'MouseX::AttributeHelpers::Trait::Base';

    sub helper_type { 'Num' }

    has 'method_constructors' => (
        is      => 'ro',
        isa     => 'HashRef',
        lazy    => 1,
        default => sub {
            return +{
                set => sub {
                    my ( $attr, $reader, $writer ) = @_;
                    return sub { $writer->( $_[0], $_[1] ) };
                },
                get => sub {
                    my ( $attr, $reader, $writer ) = @_;
                    return sub { $reader->( $_[0] ) };
                },
                add => sub {
                    my ( $attr, $reader, $writer ) = @_;
                    return sub { $writer->( $_[0], $reader->( $_[0] ) + $_[1] ) };
                },
                sub => sub {
                    my ( $attr, $reader, $writer ) = @_;
                    return sub { $writer->( $_[0], $reader->( $_[0] ) - $_[1] ) };
                },
                mul => sub {
                    my ( $attr, $reader, $writer ) = @_;
                    return sub { $writer->( $_[0], $reader->( $_[0] ) * $_[1] ) };
                },
                div => sub {
                    my ( $attr, $reader, $writer ) = @_;
                    return sub { $writer->( $_[0], $reader->( $_[0] ) / $_[1] ) };
                },
                mod => sub {
                    my ( $attr, $reader, $writer ) = @_;
                    return sub { $writer->( $_[0], $reader->( $_[0] ) % $_[1] ) };
                },
                abs => sub {
                    my ( $attr, $reader, $writer ) = @_;
                    return sub { $writer->( $_[0], abs( $reader->( $_[0] ) ) ) };
                },
            };
        }
    );


    package MouseX::AttributeHelpers::Number;
    use Mouse;

    extends 'Mouse::Meta::Attribute';
    with 'MouseX::AttributeHelpers::Trait::Number';

    no Mouse;

    # register an alias for 'metaclass'
    package Mouse::Meta::Attribute::Custom::MyNumber;
    sub register_implementation { 'MouseX::AttributeHelpers::Number' }

    # register an alias for 'traits'
    package Mouse::Meta::Attribute::Custom::Trait::MyNumber;
    sub register_implementation { 'MouseX::AttributeHelpers::Trait::Number' }

    package MyClass;
    use Mouse;

    has 'i' => (
        metaclass => 'MyNumber',
        is => 'rw',
        isa => 'Int',
        provides => {
            'add' => 'i_add',
        },
    );

    package MyClassWithTraits;
    use Mouse;

    has 'ii' => (
        isa => 'Num',
        predicate => 'has_ii',

        provides => {
            sub => 'ii_minus',
            abs => 'ii_abs',
            get => 'get_ii',
            set => 'set_ii',
       },

       traits => [qw(MyNumber)],
    );
};

can_ok 'MyClass', 'i_add';
my $k = MyClass->new(i=>3);
$k->i_add(4);
is $k->i, 7;

can_ok 'MyClassWithTraits', qw(ii_minus ii_abs);

$k = MyClassWithTraits->new(ii => 10);
$k->ii_minus(100);
is $k->get_ii, -90;
$k->ii_abs;
is $k->get_ii,  90;

$k->set_ii(10);
is $k->get_ii, 10;
$k->ii_abs;
is $k->get_ii, 10;

