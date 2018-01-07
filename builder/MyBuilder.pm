package builder::MyBuilder;
use strict;
use warnings;
use base qw(Module::Build::XSUtil);

sub new {
    my ($class, %args) = @_;
    $class->SUPER::new(
        %args,
        c_source => [ 'xs-src' ],
        generate_ppport_h => 'xs-src/ppport.h',
        generate_xshelper_h => 'xs-src/xshelper.h',
        xs_files => { 'xs-src/Mouse.xs' => 'lib/Mouse.xs' },
    );
}

sub ACTION_code {
    my ($self, @args) = @_;

    $self->run_perl_script('tool/generate-mouse-tiny.pl', [], ['lib/Mouse/Tiny.pm']) or die;

    if (!$self->pureperl_only) {
        $self->_write_xs_version;
        my @xs = qw(
            xs-src/MouseAccessor.xs
            xs-src/MouseAttribute.xs
            xs-src/MouseTypeConstraints.xs
            xs-src/MouseUtil.xs
        );
        for my $xs (@xs) {
            (my $c = $xs) =~ s/\.xs\z/.c/;
            next if $self->up_to_date($xs, $c);
            $self->compile_xs($xs, outfile => $c);
        }
    }
    $self->SUPER::ACTION_code(@args);
}

sub _write_xs_version {
    my $self = shift;
    open my $fh, '>', 'xs-src/xs_version.h' or die;
    print  {$fh} "#ifndef XS_VERSION\n";
    printf {$fh} "#define XS_VERSION \"%s\"\n", $self->dist_version;
    print  {$fh} "#endif\n";
}

sub ACTION_test {
    my ($self, @args) = @_;

    if ($ENV{COMPAT_TEST}) {
        $self->depends_on('moose_compat_test');
    }

    if (!$self->pureperl_only) {
        local $ENV{MOUSE_XS} = 1;
        $self->log_info("xs tests.\n");
        $self->SUPER::ACTION_test(@args);
    }

    {
        local $ENV{PERL_ONLY} = 1;
        $self->log_info("pureperl tests.\n");
        $self->SUPER::ACTION_test(@args);
    }
}

sub ACTION_moose_compat_test {
    my $self = shift;
    $self->depends_on('code');
    $self->run_perl_script('tool/create-moose-compatibility-tests.pl') or die;
}

1;
