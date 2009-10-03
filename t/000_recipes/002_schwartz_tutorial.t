#!/usr/bin/perl

# This adapted from the tutorial here:
# http://www.stonehenge.com/merlyn/LinuxMag/col94.html
# The Moose is Flying (part 1)'
# Using Mouse, instead

# use feature ':5.10';


use strict;
use warnings;
use Test::More;

# functions to capture the output of the tutorial
our $DUMMY_STDOUT = "";
sub dprint { $DUMMY_STDOUT .= join "", @_ };
sub stdout { my $stdout = $DUMMY_STDOUT; $DUMMY_STDOUT = ""; return $stdout }
sub say    { ::dprint $_, "\n" for @_ }

######################################################################
# This is the tutorial, as posted by Heikki Lehvaslaiho in Mouse's RT
# ticket #42992, except with print and say modified to use the above.

package Animal;
use Mouse::Role;
has 'name' => (is => 'rw');
sub speak {
    my $self = shift;
    ::dprint $self->name, " goes ", $self->sound, "\n";
}
requires 'sound';
has 'color' => (is => 'rw', default => sub { shift->default_color });
requires 'default_color';
no Mouse::Role;
1;

## Cow.pm:
package Cow;
use Mouse;
with 'Animal';
sub default_color { 'spotted' }
sub sound { 'moooooo' }
no Mouse;
1;
## Horse.pm:
package Horse;
use Mouse;
with 'Animal';
sub default_color { 'brown' }
sub sound { 'neigh' }
no Mouse;
1;
## Sheep.pm:
package Sheep;
use Mouse;
with 'Animal';
sub default_color { 'black' }
sub sound { 'baaaah' }
no Mouse;
1;

package MouseA;
use Mouse;
with 'Animal';
sub default_color { 'white' }
sub sound { 'squeak' }
after 'speak' => sub {
    ::dprint "[but you can barely hear it!]\n";
};
before 'speak' => sub {
    ::dprint "[Ahem]\n";
};
no Mouse;
1;



package Racer;
use Mouse::Role;
has $_ => (is => 'rw', default => 0)
    foreach qw(wins places shows losses);
sub won { my $self = shift; $self->wins($self->wins + 1) }
sub placed { my $self = shift; $self->places($self->places + 1) }
sub showed { my $self = shift; $self->shows($self->shows + 1) }
sub lost { my $self = shift; $self->losses($self->losses + 1) }
sub standings {
    my $self = shift;
    join ", ", map { $self->$_ . " $_" } qw(wins places shows losses);
}
no Mouse::Role;
1;



# To create the race horse, we just mix a horse with a racer:

package RaceHorse;
use Mouse;
extends 'Horse';
with 'Racer';
no Mouse;
1;


######################################################################
# Now the tests
package main;
plan tests => 5;

#use Horse;
my $talking = Horse->new(name => 'Mr. Ed');
say $talking->name;             # prints Mr. Ed
is stdout, "Mr. Ed\n";
$talking->color("grey");        # sets the color
$talking->speak;                # says "Mr. Ed goes neigh"

is stdout, <<EXPECTED;
Mr. Ed goes neigh
EXPECTED


#use Sheep;
my $baab = Sheep->new(color => 'white', name => 'Baab');
$baab->speak;                   # prints "Baab goes baaaah"
is stdout, <<EXPECTED;
Baab goes baaaah
EXPECTED

#use MouseA
my $mickey = MouseA->new(name => 'Mickey');
$mickey->speak;
is stdout, <<EXPECTED;
[Ahem]
Mickey goes squeak
[but you can barely hear it!]
EXPECTED

#use RaceHorse;
my $s = RaceHorse->new(name => 'Seattle Slew');
$s->won; $s->won; $s->won; $s->placed; $s->lost; # run some races
::dprint $s->standings, "\n";      # 3 wins, 1 places, 0 shows, 1 losses
is stdout, <<EXPECTED;
3 wins, 1 places, 0 shows, 1 losses
EXPECTED

