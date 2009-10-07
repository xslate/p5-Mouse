package Mouse::Exporter;
use strict;
use warnings;

use Carp qw(confess);

my %SPEC;

my $strict_bits = strict::bits(qw(subs refs vars));

# it must be "require", because Mouse::Util depends on Mouse::Exporter,
# which depends on Mouse::Util::import()
require Mouse::Util;

sub import{
    $^H              |= $strict_bits;         # strict->import;
    ${^WARNING_BITS}  = $warnings::Bits{all}; # warnings->import;
    return;
}


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
            push @stack, grep{ !$seen{$_}++ } ref($also) ? @{ $also } : $also;
        }
    }
    else{
        @export_from = ($exporting_package);
    }

    {
        my %exports;
        my @removables;
        my @all;

        my @init_meta_methods;

        foreach my $package(@export_from){
            my $spec = $SPEC{$package} or next;

            if(my $as_is = $spec->{as_is}){
                foreach my $thingy (@{$as_is}){
                    my($code_package, $code_name, $code);

                    if(ref($thingy)){
                        $code = $thingy;
                        ($code_package, $code_name) = Mouse::Util::get_code_info($code);
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

            if(my $init_meta = $package->can('init_meta')){
                if(!grep{ $_ == $init_meta } @init_meta_methods){
                    unshift @init_meta_methods, $init_meta;
                }
            }
        }
        $args{EXPORTS}    = \%exports;
        $args{REMOVABLES} = \@removables;

        $args{groups}{all}     ||= \@all;

        if(my $default_list = $args{groups}{default}){
            my %default;
            foreach my $keyword(@{$default_list}){
                $default{$keyword} = $exports{$keyword}
                    || confess(qq{The $exporting_package package does not export "$keyword"});
            }
            $args{DEFAULT} = \%default;
        }
        else{
            $args{groups}{default} ||= \@all;
            $args{DEFAULT}           = $args{EXPORTS};
        }

        if(@init_meta_methods){
            $args{INIT_META} = \@init_meta_methods;
        }
    }

    no strict 'refs';

    *{$exporting_package . '::import'}    = \&do_import;
    *{$exporting_package . '::unimport'}  = \&do_unimport;

    return;
}


# the entity of general import()
sub do_import {
    my($package, @args) = @_;

    my $spec = $SPEC{$package}
        || confess("The package $package package does not use Mouse::Exporter");

    my $into = _get_caller_package(ref($args[0]) ? shift @args : undef);

    my @exports;
    foreach my $arg(@args){
        if($arg =~ s/^-//){
            Mouse::Util::not_supported("-$arg");
        }
        elsif($arg =~ s/^://){
            my $group = $spec->{groups}{$arg}
                || confess(qq{The $package package does not export the group "$arg"});
            push @exports, @{$group};
        }
        else{
            push @exports, $arg;
        }
    }

    $^H              |= $strict_bits;         # strict->import;
    ${^WARNING_BITS}  = $warnings::Bits{all}; # warnings->import;

    if($into eq 'main' && !$spec->{_export_to_main}){
        warn qq{$package does not export its sugar to the 'main' package.\n};
        return;
    }

    if($spec->{INIT_META}){
        foreach my $init_meta(@{$spec->{INIT_META}}){
            $into->$init_meta(for_class => $into);
        }

        # _apply_meta_traits($into); # TODO
    }

    if(@exports){
        foreach my $keyword(@exports){
            no strict 'refs';
            *{$into.'::'.$keyword} = $spec->{EXPORTS}{$keyword}
                || confess(qq{The $package package does not export "$keyword"});
        }
    }
    else{
        my $default = $spec->{DEFAULT};
        while(my($keyword, $code) = each %{$default}){
            no strict 'refs';
            *{$into.'::'.$keyword} = $code;
        }
    }
    return;
}

# the entity of general unimport()
sub do_unimport {
    my($package, $arg) = @_;

    my $spec = $SPEC{$package}
        || confess("The package $package does not use Mouse::Exporter");

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
