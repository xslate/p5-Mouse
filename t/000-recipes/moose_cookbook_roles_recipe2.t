#!/usr/bin/perl -w

use strict;
use Test::More 'no_plan';
use Test::Exception;
$| = 1;



# =begin testing SETUP
{

  package Restartable;
  use Mouse::Role;

  has 'is_paused' => (
      is      => 'rw',
      isa     => 'Bool',
      default => 0,
  );

  requires 'save_state', 'load_state';

  sub stop { 1 }

  sub start { 1 }

  package Restartable::ButUnreliable;
  use Mouse::Role;

  with 'Restartable' => {
      -alias => {
          stop  => '_stop',
          start => '_start'
      },
      -excludes => [ 'stop', 'start' ],
  };

  sub stop {
      my $self = shift;

      $self->explode() if rand(1) > .5;

      $self->_stop();
  }

  sub start {
      my $self = shift;

      $self->explode() if rand(1) > .5;

      $self->_start();
  }

  package Restartable::ButBroken;
  use Mouse::Role;

  with 'Restartable' => { -excludes => [ 'stop', 'start' ] };

  sub stop {
      my $self = shift;

      $self->explode();
  }

  sub start {
      my $self = shift;

      $self->explode();
  }
}



# =begin testing
{
{
    my $unreliable = Mouse::Meta::Class->create_anon_class(
        superclasses => [],
        roles        => [qw/Restartable::ButUnreliable/],
        methods      => {
            explode      => sub { },    # nop.
            'save_state' => sub { },
            'load_state' => sub { },
        },
    )->new_object();
    ok( $unreliable, 'made anon class with Restartable::ButUnreliable role' );
    can_ok( $unreliable, qw/start stop/ );
}

{
    my $cnt    = 0;
    my $broken = Mouse::Meta::Class->create_anon_class(
        superclasses => [],
        roles        => [qw/Restartable::ButBroken/],
        methods      => {
            explode      => sub { $cnt++ },
            'save_state' => sub { },
            'load_state' => sub { },
        },
    )->new_object();

    ok( $broken, 'made anon class with Restartable::ButBroken role' );

    $broken->start();

    is( $cnt, 1, '... start called explode' );

    $broken->stop();

    is( $cnt, 2, '... stop also called explode' );
}
}




1;
