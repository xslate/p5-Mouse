package BaseClass;
use Mouse;

sub import {
    my $pkg = caller(0);
    Mouse->import({into_level => 1});
    $pkg->meta->add_method('foo' => sub {'bar'});
}

1;
