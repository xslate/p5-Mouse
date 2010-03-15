#!perl
package IntStack;
use Mouse;

has storage => (
    is => 'ro',
    isa => 'ArrayRef[Int]',

    default => sub{ [] },
    traits  => [qw(Array)],

    handles => {
        push => 'push',
        pop  => 'pop',
        top  => [ get => -1 ],
    },
);

__PACKAGE__->meta->make_immutable();

package main;

my $stack = IntStack->new;

$stack->push(42);
$stack->push(27);

print $stack->pop, "\n";
print $stack->top, "\n";

