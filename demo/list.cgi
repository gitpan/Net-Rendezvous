#!/usr/bin/perl

use Net::Rendezvous;
use CGI qw(:standard);

print header, start_html('Rendezvous Websites'), h1('Rendezvous Websites'),
	hr;

my $res = new Net::Rendezvous('http');
$res->discover;

foreach $entry ( $res->entries ) {
	my $url = sprintf 'http://%s:%s%s', $entry->address, $entry->port,
		$entry->attribute('path');
	print a({-href=> $url}, $entry->name), br;
}
