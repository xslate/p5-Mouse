#!/usr/bin/env perl
use Test::More;

my $id = 0;
foreach my $mod (qw(Mouse Mouse::Role Mouse::Exporter)){
    $id++;
    eval qq{
        no strict;
        no warnings;

        package Class$id;
        use $mod;

        my \$foo = 'foo';
        chop \$\$foo;
    };
    like $@, qr/Can't use string \("foo"\) as a SCALAR ref while "strict refs" in use /, # '
      "using $mod turns on strictures";

    my @warnings;
    local $SIG{__WARN__} = sub {
        push @warnings, @_;
    };

    $id++;
    eval qq{
        no strict;
        no warnings;

        package Class$id;
        use $mod;

        my \$one = 1 + undef;
    };
    is $@, '';

    like("@warnings", qr/^Use of uninitialized value/, "using $mod turns on warnings");
}

done_testing;
