#!/usr/bin/perl -w

use strict;
use Test::More 'no_plan';
use Test::Exception;
$| = 1;



# =begin testing SETUP
{

  package MyApp::Meta::Attribute::Trait::Labeled;
  use Mouse::Role;

  has label => (
      is        => 'rw',
      isa       => 'Str',
      predicate => 'has_label',
  );

  package Mouse::Meta::Attribute::Custom::Trait::Labeled;
  sub register_implementation {'MyApp::Meta::Attribute::Trait::Labeled'}

  package MyApp::Website;
  use Mouse;

  has url => (
      traits => [qw/Labeled/],
      is     => 'rw',
      isa    => 'Str',
      label  => "The site's URL",
  );

  has name => (
      is  => 'rw',
      isa => 'Str',
  );

  sub dump {
      my $self = shift;

      my $dump = '';

      for my $name ( sort $self->meta->get_attribute_list ) {
          my $attribute = $self->meta->get_attribute($name);

          if (   $attribute->does('MyApp::Meta::Attribute::Trait::Labeled')
              && $attribute->has_label ) {
              $dump .= $attribute->label;
          }
          else {
              $dump .= $name;
          }

          my $reader = $attribute->get_read_method_ref;
          $dump .= ": " . $reader->($self) . "\n";
      }

      return $dump;
  }

  package main;

  my $app = MyApp::Website->new( url => "http://google.com", name => "Google" );
}



# =begin testing
{
my $app2
    = MyApp::Website->new( url => "http://google.com", name => "Google" );
is(
    $app2->dump, q{name: Google
The site's URL: http://google.com
}, '... got the expected dump value'
);
}




1;
