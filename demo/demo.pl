#!/usr/bin/perl

use Net::Rendezvous;

my $res = new Net::Rendezvous($ARGV[0]);
$res->discover;

foreach $entry ( $res->entries ) {
	printf "%s %s:%s\n",  $entry->name, $entry->hostname, $entry->port;
}
