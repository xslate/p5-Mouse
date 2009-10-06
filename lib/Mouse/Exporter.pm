package Mouse::Exporter;
use strict;
use warnings;

use Carp qw(confess);

use Mouse::Util qw(get_code_info);

my %SPEC;

sub setup_import_methods{
    my($class, %args) = @_;

    my $exporting_package = $args{exporting_package} ||= caller();

    $SPEC{$exporting_package} = \%args;

    # canonicalize args
    my @export_from;
    if($args{also}){
        my %seen;
        my @stack = ($exporting_package);

        while(my $current = shift @stack){
            push @export_from, $current;

            my $also = $SPEC{$current}{also} or next;
            push @stack, grep{ !$seen{$_}++ } @{ $also };
        }
    }
    else{
        @export_from = ($exporting_package);
    }

    {
        my %exports;
        my @removables;
        my @all;

        foreach my $package(@export_from){
            my $spec = $SPEC{$package} or next;

            if(my $as_is = $spec->{as_is}){
                foreach my $thingy (@{$as_is}){
                    my($code_package, $code_name, $code);

                    if(ref($thingy)){
                        $code = $thingy;
                        ($code_package, $code_name) = get_code_info($code);
                    }
                    else{
                        no strict 'refs';
                        $code_package = $package;
                        $code_name    = $thingy;
                        $code         = \&{ $code_package . '::' . $code_name };
                   }

                    push @all, $code_name;
                    $exports{$code_name} = $code;
                    if($code_package eq $package){
                        push @removables, $code_name;
                    }
                }
            }
        }
        $args{EXPORTS}    = \%exports;
        $args{REMOVABLES} = \@removables;

        $args{group}{default} ||= \@all;
        $args{group}{all}     ||= \@all;
    }

    no strict 'refs';

    *{$exporting_package . '::import'}    = \&do_import;
    *{$exporting_package . '::unimport'}  = \&do_unimport;

    if(!defined &{$exporting_package . '::init_meta'}){
        *{$exporting_package . '::init_meta'} = \&do_init_meta;
    }
    return;
}

# the entity of general init_meta()
sub do_init_meta {
    my($class, %args) = @_;

    my $spec = $SPEC{$class}
        or confess("The package $class does not use Mouse::Exporter");

    my $for_class = $args{for_class}
        or confess("Cannot call init_meta without specifying a for_class");

    my $base_class = $args{base_class} || 'Mouse::Object';
    my $metaclass  = $args{metaclass}  || 'Mouse::Meta::Class';

    my $meta = $metaclass->initialize($for_class);

    $meta->add_method(meta => sub{
        $metaclass->initialize(ref($_[0]) || $_[0]);
    });

    $meta->superclasses($base_class)
        unless $meta->superclasses;

    return $meta;
}

# the entity of general import()
sub do_import {
    my($class, @args) = @_;

    my $spec = $SPEC{$class}
        or confess("The package $class does not use Mouse::Exporter");

    my $into = _get_caller_package(ref($args[0]) ? shift @args : undef);

    my @exports;
    foreach my $arg(@args){
        if($arg =~ s/^[-:]//){
            my $group = $spec->{group}{$arg} or confess(qq{group "$arg" is not exported by the $class module});
            push @exports, @{$group};
        }
        else{
            push @exports, $arg;
        }
    }

    strict->import;
    warnings->import;

    if($into eq 'main' && !$spec->{_not_export_to_main}){
        warn qq{$class does not export its sugar to the 'main' package.\n};
        return;
    }

    if($class->can('init_meta')){
        my $meta = $class->init_meta(
            for_class  => $into,
        );

        # TODO: process -metaclass and -traits
        # ...
    }


    my $exports_ref = @exports ? \@exports : $spec->{group}{default};

    foreach my $keyword(@{$exports_ref}){
        no strict 'refs';
        *{$into.'::'.$keyword} = $spec->{EXPORTS}{$keyword}
            or confess(qq{"$keyword" is not exported by the $class module});
    }
    return;
}

# the entity of general unimport()
sub do_unimport {
    my($class, $arg) = @_;

    my $spec = $SPEC{$class}
        or confess("The package $class does not use Mouse::Exporter");

    my $from = _get_caller_package($arg);

    my $stash = do{
        no strict 'refs';
        \%{$from . '::'}
    };

    for my $keyword (@{ $spec->{REMOVABLES} }) {
        my $gv = \$stash->{$keyword};
        if(ref($gv) eq 'GLOB' && *{$gv}{CODE} == $spec->{EXPORTS}{$keyword}){ # make sure it is from us
            delete $stash->{$keyword};
        }
    }
    return;
}

sub _get_caller_package {
    my($arg) = @_;

    # 2 extra level because it's called by import so there's a layer
    # of indirection
    my $offset = 1;

    if(ref $arg){
        return defined($arg->{into})       ? $arg->{into}
             : defined($arg->{into_level}) ? scalar caller($offset + $arg->{into_level})
             :                               scalar caller($offset);
    }
    else{
        return scalar caller($offset);
    }
}

1;

__END__

=head1 NAME

Mouse - The Mouse Exporter

=head1 SYNOPSIS

    package MouseX::Foo;
    use Mouse::Exporter;

    Mouse::Exporter->setup_import_methods(

    );

=head1 DESCRIPTION


=head1 SEE ALSO

L<Moose::Exporter>

=cut
