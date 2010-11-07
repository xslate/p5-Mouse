#!perl -w

use strict;
use Config; printf "Perl/%vd (%s)\n", $^V, $Config{archname};

use Benchmark qw(:hireswallclock);
use Benchmark::Forking qw(cmpthese);

use Encode (); # pre-load for Interface::Test
use HTTP::Request ();

sub new_he{
    my($use_pp, $any_moose) = @_;
    $ENV{MOUSE_PUREPERL} = $use_pp;
    $ENV{ANY_MOOSE}      = $any_moose if defined $any_moose;

    require HTTP::Engine;

    return HTTP::Engine->new(
        interface       => {
            module => 'Test',
            request_handler => sub {
                my($request) = @_;

                return HTTP::Engine::Response->new(body => "Hello, world!\n");
            },
        },
    );
}

my $req = HTTP::Request->new(GET => 'http://localhost/');

print "load HTTP::Engine, new(), and run()\n";
cmpthese -2 => {
     'XS' => sub {
        my $he  = new_he(0);
        $he->run($req, env => \%ENV);
     },
     'PP' => sub {
        my $he  = new_he(1);
        $he->run($req, env => \%ENV);
     },
     'Moose' => sub {
        my $he  = new_he(0, 'Moose');
        $he->run($req, env => \%ENV);
     },
};

print "load HTTP::Engine, new(), and run() * 100\n";
cmpthese -2 => {
     'XS' => sub {
        my $he  = new_he(0);
        $he->run($req, env => \%ENV) for 1 .. 100;
     },
     'PP' => sub {
        my $he = new_he(1);
        $he->run($req, env => \%ENV) for 1 .. 100;
     },
     'Moose' => sub {
        my $he = new_he(0, 'Moose');
        $he->run($req, env => \%ENV) for 1 .. 100;
     },
};

