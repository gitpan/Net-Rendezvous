use Test::More tests => 9;

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
