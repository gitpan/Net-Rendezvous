use Test::More tests => 12;

BEGIN { use_ok('Net::Rendezvous') };

use strict;

my $res;
ok( $res = Net::Rendezvous->new,			'constructor');
ok( $res->application('ftp'),				'application set');
ok( $res->domain('zeroconf.org'),			'domain set');
ok( $res->domain eq 'zeroconf.org',			'domain get');
ok( $res->application eq '_ftp._tcp.zeroconf.org',	'application get');
ok( $res->discover,					'discover');
my @entries;
ok( @entries = sort( {$a->name cmp $b->name} $res->entries),	'entries');
ok( $#entries == 2,					'entry count');
ok( $entries[0]->name eq 'apple quicktime files',	'entry 1 check');
ok( $entries[1]->name eq 'microsoft developer files',	'entry 2 check');
ok( $entries[2]->name eq "registered users' only",	'entry 3 check');
