#!perl
# https://rt.cpan.org/Ticket/Display.html?id=73592
use Test::More tests => 2;

sub TIESCALAR { bless [] }
# Load Carp before tying as it uses Exporter, and Exporter < 5.66 has the
# local $_ bug.
require Carp;
eval { require Carp::Heavy };
tie $_, "";

{
    package Human;

    use Mouse;
    use Mouse::Util::TypeConstraints;

    coerce 'Human::EyeColor'
        => from 'ArrayRef'
        => via { return Human::EyeColor->new(); };

    has 'eye_color' => (
        is       => 'ro',
        isa      => 'Human::EyeColor',
        coerce   => 1,
    );

    subtype 'NonemptyStr'
        => as 'Str'
        => where { length $_ }
        => message { "The string is empty!" };

    has name => (
        is  => 'ro',
        isa => 'NonemptyStr',
    );
}

{
    package Human::EyeColor;

    use Mouse;
}

ok eval {
    my $person = Human->new(
        eye_color => [ qw( blue blue blue blue ) ],
    );
    1
   }, 'coercion does not interfere with $_';

eval {
    my $person = Human->new(name => '');
};
like $@, qr/The string is empty/,
    'type constraint messages do not interfere with $_';
