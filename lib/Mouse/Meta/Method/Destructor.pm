package Mouse::Meta::Method::Destructor;
use Mouse::Util; # enables strict and warnings

sub _empty_DESTROY{ }

sub _generate_destructor{
    my (undef, $metaclass) = @_;

    if(!$metaclass->name->can('DEMOLISH')){
        return \&_empty_DESTROY;
    }

    my $demolishall = '';
    for my $class ($metaclass->linearized_isa) {
        no strict 'refs';
        if (*{$class . '::DEMOLISH'}{CODE}) {
            $demolishall .= "${class}::DEMOLISH(\$self);\n";
        }
    }

    my $source = sprintf("#line %d %s\n", __LINE__, __FILE__) . <<"...";
    sub {
        my \$self = shift;
        $demolishall;
    }
...

    my $code;
    my $e = do{
        local $@;
        $code = eval $source;
        $@;
    };
    die $e if $e;
    return $code;
}

1;
__END__
