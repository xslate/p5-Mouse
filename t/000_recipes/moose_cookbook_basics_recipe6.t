#!/usr/bin/perl -w

use strict;
use Test::More 'no_plan';
use Test::Exception;
$| = 1;



# =begin testing SETUP
{

  package Document::Page;
  use Mouse;

  has 'body' => ( is => 'rw', isa => 'Str', default => sub {''} );

  sub create {
      my $self = shift;
      $self->open_page;
      inner();
      $self->close_page;
  }

  sub append_body {
      my ( $self, $appendage ) = @_;
      $self->body( $self->body . $appendage );
  }

  sub open_page  { (shift)->append_body('<page>') }
  sub close_page { (shift)->append_body('</page>') }

  package Document::PageWithHeadersAndFooters;
  use Mouse;

  extends 'Document::Page';

  augment 'create' => sub {
      my $self = shift;
      $self->create_header;
      inner();
      $self->create_footer;
  };

  sub create_header { (shift)->append_body('<header/>') }
  sub create_footer { (shift)->append_body('<footer/>') }

  package TPSReport;
  use Mouse;

  extends 'Document::PageWithHeadersAndFooters';

  augment 'create' => sub {
      my $self = shift;
      $self->create_tps_report;
      inner();
  };

  sub create_tps_report {
      (shift)->append_body('<report type="tps"/>');
  }

  # <page><header/><report type="tps"/><footer/></page>
  my $report_xml = TPSReport->new->create;
}



# =begin testing
{
my $tps_report = TPSReport->new;
isa_ok( $tps_report, 'TPSReport' );

is(
    $tps_report->create,
    q{<page><header/><report type="tps"/><footer/></page>},
    '... got the right TPS report'
);
}




1;
