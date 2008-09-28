#!/usr/bin/env perl
package Mouse::Util;
use strict;
use warnings;
use base 'Exporter';

our %dependencies = (
    'Scalar::Util' => {

#       VVVVV   CODE TAKEN FROM SCALAR::UTIL   VVVVV
        'blessed' => do {
            *UNIVERSAL::a_sub_not_likely_to_be_here = sub {
                my $ref = ref($_[0]);

                # deviation from Scalar::Util
                # XS returns undef, PP returns GLOB.
                # let's make that more consistent by having PP return
                # undef if it's a GLOB. :/

                # \*STDOUT would be allowed as an object in PP blessed
                # but not XS
                return $ref eq 'GLOB' ? undef : $ref;
            };

            sub {
                local($@, $SIG{__DIE__}, $SIG{__WARN__});
                length(ref($_[0]))
                    ? eval { $_[0]->a_sub_not_likely_to_be_here }
                    : undef;
            },
        },
        'looks_like_number' => sub {
            local $_ = shift;

            # checks from perlfaq4
            return 0 if !defined($_) or ref($_);
            return 1 if (/^[+-]?\d+$/); # is a +/- integer
            return 1 if (/^([+-]?)(?=\d|\.\d)\d*(\.\d*)?([Ee]([+-]?\d+))?$/); # a C float
            return 1 if ($] >= 5.008 and /^(Inf(inity)?|NaN)$/i) or ($] >= 5.006001 and /^Inf$/i);

            0;
        },
        'reftype' => sub {
            local($@, $SIG{__DIE__}, $SIG{__WARN__});
            my $r = shift;
            my $t;

            length($t = ref($r)) or return undef;

            # This eval will fail if the reference is not blessed
            eval { $r->a_sub_not_likely_to_be_here; 1 }
            ? do {
                $t = eval {
                    # we have a GLOB or an IO. Stringify a GLOB gives it's name
                    my $q = *$r;
                    $q =~ /^\*/ ? "GLOB" : "IO";
                }
                or do {
                    # OK, if we don't have a GLOB what parts of
                    # a glob will it populate.
                    # NOTE: A glob always has a SCALAR
                    local *glob = $r;
                    defined *glob{ARRAY} && "ARRAY"
                        or defined *glob{HASH} && "HASH"
                        or defined *glob{CODE} && "CODE"
                        or length(ref(${$r})) ? "REF" : "SCALAR";
                }
            }
            : $t
        },
        'openhandle' => sub {
            my $fh = shift;
            my $rt = reftype($fh) || '';

            return defined(fileno($fh)) ? $fh : undef
                if $rt eq 'IO';

            if (reftype(\$fh) eq 'GLOB') { # handle  openhandle(*DATA)
                $fh = \(my $tmp=$fh);
            }
            elsif ($rt ne 'GLOB') {
                return undef;
            }

            (tied(*$fh) or defined(fileno($fh)))
                ? $fh : undef;
        },
        weaken => {
            loaded => \&Scalar::Util::weaken,
            not_loaded => sub { die "Scalar::Util required for weak reference support" },
        },
#       ^^^^^   CODE TAKEN FROM SCALAR::UTIL   ^^^^^
    },
    'MRO::Compat' => {
#       VVVVV   CODE TAKEN FROM MRO::COMPAT   VVVVV
        'get_linear_isa' => {
            loaded     => \&mro::get_linear_isa,
            not_loaded => do {
                # this recurses so it isn't pretty
                my $code;
                $code = sub {
                    no strict 'refs';

                    my $classname = shift;

                    my @lin = ($classname);
                    my %stored;
                    foreach my $parent (@{"$classname\::ISA"}) {
                        my $plin = $code->($parent);
                        foreach (@$plin) {
                            next if exists $stored{$_};
                            push(@lin, $_);
                            $stored{$_} = 1;
                        }
                    }
                    return \@lin;
                }
            },
        },
#       ^^^^^   CODE TAKEN FROM MRO::COMPAT   ^^^^^
    },
#       VVVVV   CODE TAKEN FROM TEST::EXCEPTION   VVVVV
    'Test::Exception' => do {

        my $Tester = Test::Builder->new;

        my $is_exception = sub {
            my $exception = shift;
            return ref $exception || $exception ne '';
        };

        my $exception_as_string = sub {
            my ( $prefix, $exception ) = @_;
            return "$prefix normal exit" unless $is_exception->( $exception );
            my $class = ref $exception;
            $exception = "$class ($exception)"
                    if $class && "$exception" !~ m/^\Q$class/;
            chomp $exception;
            return "$prefix $exception";
        };
        my $try_as_caller = sub {
            my $coderef = shift;
            eval { $coderef->() };
            $@;
        };

        {
            'throws_ok' => sub (&$;$) {
                my ( $coderef, $expecting, $description ) = @_;
                Carp::croak "throws_ok: must pass exception class/object or regex"
                    unless defined $expecting;
                $description = $exception_as_string->( "threw", $expecting )
                    unless defined $description;
                my $exception = $try_as_caller->($coderef);

                my $regex = $Tester->maybe_regex( $expecting );
                my $ok = $regex
                    ? ( $exception =~ m/$regex/ )
                    : eval {
                        $exception->isa( ref $expecting ? ref $expecting : $expecting )
                    };
                $Tester->ok( $ok, $description );
                unless ( $ok ) {
                    $Tester->diag( $exception_as_string->( "expecting:", $expecting ) );
                    $Tester->diag( $exception_as_string->( "found:", $exception ) );
                };
                $@ = $exception;
                return $ok;
            },
            'lives_ok' => sub (&;$) {
                my ( $coderef, $description ) = @_;
                my $exception = $try_as_caller->( $coderef );
                my $ok = $Tester->ok( ! $is_exception->( $exception ), $description );
                $Tester->diag( $exception_as_string->( "died:", $exception ) ) unless $ok;
                $@ = $exception;
                return $ok;
            },
        },
    },
);

our %loaded;

our @EXPORT_OK = map { keys %$_ } values %dependencies;
our %EXPORT_TAGS = (
    all  => \@EXPORT_OK,
    test => [qw/throws_ok lives_ok/],
);

for my $module_name (keys %dependencies) {
    my $loaded = do {
        local $SIG{__DIE__} = 'DEFAULT';
        eval "require $module_name; 1";
    };

    $loaded{$module_name} = $loaded;

    for my $method_name (keys %{ $dependencies{ $module_name } }) {
        my $producer = $dependencies{$module_name}{$method_name};
        my $implementation;

        if (ref($producer) eq 'HASH') {
            $implementation = $loaded
                            ? $producer->{loaded}
                            : $producer->{not_loaded};
        }
        else {
            $implementation = $loaded
                            ? $module_name->can($method_name)
                            : $producer;
        }

        no strict 'refs';
        *{ __PACKAGE__ . '::' . $method_name } = $implementation;
    }
}

1;

__END__

=head1 NAME

Mouse::Util - features, with or without their dependencies

=head1 IMPLEMENTATIONS FOR

=head2 L<MRO::Compat>

=head3 get_linear_isa

=head2 L<Scalar::Util>

=head3 blessed

=head3 looks_like_number

=head3 reftype

=head3 openhandle

=head3 weaken

C<weaken> I<must> be implemented in XS. If the user tries to use C<weaken>
without L<Scalar::Util>, an error is thrown.

=head2 Test::Exception

=head3 throws_ok

=head3 lives_ok

=cut

