#!perl -w
use strict;

my $tb_version = `$^X -e "use Test::Builder; print Test::Builder->VERSION"`;
if($tb_version == 2.0001 && $] <= 5.010_000) {
    require Test::More;
    Test::More::plan( skip_all => 'Test::Builder 2.00_01 has a problem' );
}
else {
    require Mouse;
    require Test::More;
    Test::More::plan( tests => 1 );
    Test::More::pass('loads Test::More after loading Mouse');
}

