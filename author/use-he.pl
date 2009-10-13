#!perl -w

use strict;
use HTTP::Engine;

my $engine = HTTP::Engine->new(
    interface       => {
        module => 'CGI',
        request_handler => \&handle_request,
    },
);

$engine->run();

sub handle_request{
    my($request) = @_;

    return HTTP::Engine::Response->new(body => "Hello, world!\n");
}
