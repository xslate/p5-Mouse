use strict;
use warnings;
use Test::More tests => 18;
use Test::Exception;
use Scalar::Util qw/isweak/;

{
    package Headers;
    use Mouse;
    has data => (
        is => 'rw',
        isa => 'Str',
    );
    no Mouse;
}

{
    package Types;
    use MouseX::Types -declare => [qw/Foo/];
    use MouseX::Types::Mouse 'HashRef';
    class_type Foo, { class => 'Headers' };
    coerce Foo,
        from HashRef,
        via {
        Headers->new($_);
    };
}


&main; exit;

sub construct {
    my $class = shift;
    eval <<"...";
    package $class;
    use Mouse;
    BEGIN { Types->import('Foo') }
    has bone => (
        is => 'rw',
        required => 1,
    );
    has foo => (
        is     => 'rw',
        isa    => Foo,
        coerce => 1,
    );
    has weak_foo => (
        is       => 'rw',
        weak_ref => 1,
    );
    has trigger_foo => (
        is => 'rw',
        trigger => sub { \$_[0]->bone('eat') },
    );
    sub BUILD { main::ok "calling BUILD in SoftDog" }
    no Mouse;
...
    die $@ if $@;
}

sub test {
    my $class = shift;
    lives_ok { $class->new(bone => 'moo') } "$class new";
    throws_ok { $class->new() } qr/\QAttribute (bone) is required/;
    is($class->new(bone => 'moo', foo => { data => 3 })->foo->data, 3);

    my $foo = Headers->new();
    ok(Scalar::Util::isweak($class->new(bone => 'moo', weak_foo => $foo)->{weak_foo}));

    {
        my $o = $class->new(bone => 'moo');
        $o->trigger_foo($foo);
        is($o->bone, 'eat');
    }
}

sub main {
    construct('SoftDog');
    test('SoftDog');

    construct('HardDog');
    HardDog->meta->make_immutable;
    test('HardDog');
}

