#!/usr/bin/perl

use Net::Rendezvous;

my $res = new Net::Rendezvous($ARGV[0]);
print $res->domain($ARGV[1]), "\n";
$res->discover;

foreach $entry ( $res->entries ) {
	printf "%s %s:%s\n",  $entry->name, $entry->hostname, $entry->port;
}
