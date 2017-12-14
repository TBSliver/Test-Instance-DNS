#! /usr/bin/env perl
package Test::Instance::DNS::Server;

use MooX::Options::Actions;
use Net::EmptyPort qw/ empty_port /;
use Net::DNS::Nameserver;
use Net::DNS::ZoneFile;

option listen_port => (
  is => 'lazy',
  format => 'i',
  doc => 'Listen Port',
  builder => sub {
    return empty_port;
  },
);

option verbose => (
  is => 'ro',
  default => 0,
  doc => 'Turn on Verbose Debugging',
);

option zone => (
  is => 'ro',
  format => 's',
  required => 1,
  doc => 'The zone file to use',
);

has ns => (
  is => 'lazy',
  builder => sub {
    my $self = shift;
    return Net::DNS::Nameserver->new(
      LocalPort => $self->listen_port,
      ReplyHandler => sub { $self->reply_handler( @_ ) },
      Verbose => $self->verbose,
    ) || die "Couldn't create nameserver object\n";
  },
);

has _zone_file => (
  is => 'lazy',
  builder => sub {
    my $self = shift;
    return Net::DNS::ZoneFile->new( $self->zone );
  },
);

has _zone_data => (
  is => 'lazy',
  builder => sub {
    my $self = shift;
    return [ $self->_zone_file->read ];
  },
);

has _zone_lookup => (
  is => 'lazy',
  builder => sub {
    my $self = shift;
    my $data = {};
    for my $zone ( @{ $self->_zone_data } ) {
      my $ref = ref( $zone );
      my ( $type ) = $ref =~ /^.*::(.*)$/;
      push @{ $data->{$type} }, $zone;
    }
    return $data;
  },
);

has _is_running => (
  is => 'rwp',
  default => 1,
);

sub BUILD {
  my $self = shift;
  $SIG{'INT'} = sub { $self->sig_handler( @_ ) };
  $SIG{'TERM'} = sub { $self->sig_handler( @_ ) };
}

sub cmd_run {
  my $self = shift;
  $self->parse_zone;
  print "Creating Nameserver on port " . $self->listen_port . "\n";

  # same as calling main_loop on the Nameserver, but with a dropout
  while ( $self->_is_running ) {
    $self->ns->loop_once(10);
  }
}

sub sig_handler {
  my $self = shift;
  $self->_set__is_running(0);
  print "Stopping Nameserver on port " . $self->listen_port . "\n";
}


sub parse_zone {
  my $self = shift;
  use Devel::Dwarn;

  Dwarn $self->_zone_lookup;
}

sub lookup_records {
  my $self = shift;
  my ( $qtype, $qname ) = @_;
  my @ans;
  for my $rr ( @{ $self->_zone_lookup->{ $qtype } } ) {
    push @ans, $rr if $rr->owner eq $qname;
  }
  return @ans; 
}

sub reply_handler {
  my $self = shift;

  my ( $qname, $qclass, $qtype, $peerhost, $query, $conn ) = @_;
  my ( $rcode, @ans, @auth, @add );

  print "Received query from $peerhost to " . $conn->{sockhost} . "\n";
  $query->print;

  $rcode = "NOERROR";
  if ( $qtype eq "A" ) {
    push @ans, $self->lookup_a_records( $qtype, $qname );
    $rcode = "NXDOMAIN" unless scalar(@ans);
  } elsif ( $qtype eq "AAAA" ) {
    push @ans, $self->lookup_a_records( $qtype, $qname );
    $rcode = "NXDOMAIN" unless scalar(@ans);
  } else {
    if ( exists $self->_zone_lookup->{ $qtype } ) {
      Dwarn $self->_zone_lookup->{ $qtype };
    }
    $rcode = "NXDOMAIN";
  }

  # mark the answer as authoritative (by setting the 'aa' flag)
  my $headermask = {aa => 1};

  # specify EDNS options  { option => value }
  my $optionmask = {};

  return ( $rcode, \@ans, \@auth, \@add, $headermask, $optionmask );
}

sub _run_if_script {
  unless ( caller(1) ) {
    Test::Instance::DNS::Server->new_with_actions;
  }
  return 1;
}

Test::Instance::DNS::Server->_run_if_script;
