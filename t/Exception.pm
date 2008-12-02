package t::Exception;
use strict;
use warnings;
use base qw/Exporter/;

our @EXPORT = qw/throws_ok lives_ok/;

my $Tester;

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

sub throws_ok (&$;$) {
    my ( $coderef, $expecting, $description ) = @_;
    Carp::croak "throws_ok: must pass exception class/object or regex"
        unless defined $expecting;
    $description = $exception_as_string->( "threw", $expecting )
        unless defined $description;
    my $exception = $try_as_caller->($coderef);

    $Tester ||= Test::Builder->new;

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
}

sub lives_ok (&;$) {
    my ( $coderef, $description ) = @_;
    my $exception = $try_as_caller->( $coderef );

    $Tester ||= Test::Builder->new;

    my $ok = $Tester->ok( ! $is_exception->( $exception ), $description );
    $Tester->diag( $exception_as_string->( "died:", $exception ) ) unless $ok;
    $@ = $exception;
    return $ok;
}

1;
