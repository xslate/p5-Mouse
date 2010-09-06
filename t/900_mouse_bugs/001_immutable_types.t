use strict;
use warnings;
use Test::More tests => 4;
use Mouse::Util::TypeConstraints;

subtype 'Foo', as 'Object', where { $_->isa('A') };

{
    package A;
    use Mouse;
    has data => ( is => 'rw', isa => 'Str' );
}

{
    package C;
    use Mouse;
    has a => ( is => 'rw', isa => 'Foo' );
}

isa_ok(C->new(a => A->new()), 'C');
C->meta->make_immutable;
isa_ok(C->new(a => A->new()), 'C');



# The BUILD invocation order used to get reversed after
# making a class immutable.  This checks it is correct.
{
    package D;
    use Mouse;

    # we'll keep
    has order => 
        (is => 'ro', 
         default => sub {[]});

    sub BUILD { push @{shift->order}, 'D' }

    package E;
    use Mouse;
    extends 'D';

    sub BUILD { push @{shift->order}, 'E' }

    package F;
    use Mouse;
    extends 'E';

    sub BUILD { push @{shift->order}, 'F' }


}

my $obj = F->new;

print join(", ", @{$obj->order}),"\n";
is_deeply $obj->order, [qw(D E F)], "mutable BUILD invocation order correct";

# now make the classes immutable
$_->meta->make_immutable for qw(D E F);

my $obj2 = F->new;

print join(", ", @{$obj2->order}),"\n";
is_deeply $obj2->order, [qw(D E F)], "immutable BUILD invocation order still correct";


