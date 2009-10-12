#!/usr/bin/env perl
use strict;
use warnings;
use Test::More tests => 3;

# this tests that multiple type coercions on a given attribute get
# applied in the expected order.

{
    package Date;
    use Mouse;
    # This is just a simple class representing a date - in real life we'd use DateTime.

    has 'year' => 
        (is => 'rw',
         isa => 'Int');
    has 'month' => 
        (is => 'rw',
         isa => 'Int');
    has 'day' => 
        (is => 'rw',
         isa => 'Int');

    sub from_epoch
    {
        my $class = shift;
        my %d; @d{qw(year month day)} = (gmtime shift)[5,4,3];
        $d{year} += 1900;
        $d{month} += 1;
        Date->new(%d);
    }

    sub from_string
    {
        my $class = shift;
        my %d; @d{qw(year month day)} = split /\W/, shift;
        Date->new(%d);
    }


    sub to_string
    {
        my $self = shift;
        sprintf "%4d-%02d-%02d", 
            $self->year,
            $self->month,
            $self->day
    }

    package Event;
    use Mouse;
    use Mouse::Util::TypeConstraints;

    # These coercions must be applied in the right order - since a
    # number can be interpreted as a string, but not vice-versa, the
    # Int coercion should be applied first to get a correct answer.
    coerce 'Date' 
        => from 'Int' # a timestamp
            => via { Date->from_epoch($_) }

        => from 'Str' # <YYYY>-<MM>-<DD> 
            => via { Date->from_string($_) };



    has date =>
        (is => 'rw',
         isa => 'Date',
         coerce => 1);       
        
}

my $date = Date->new(year => 2001, month => 1, day => 1);
my $str = $date->to_string;
is $str, "2001-01-01", "initial date is correct: $str";

my $event = Event->new(date => $date);

$str = $event->date->to_string;
is $str, "2001-01-01", "initial date field correct: $str";

# check the order is applied correctly when given an Int
my $timestamp = 1238778317; # Fri Apr  3 17:05:17 2009
$event->date($timestamp);

$str = $event->date->to_string;
is $str, "2009-04-03", "coerced timestamp $timestamp to date field $str correctly";

