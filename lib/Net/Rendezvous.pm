package Net::Rendezvous;

=head1 NAME

Net::Rendezvous - Module for DNS service discovery (Apple's Rendezvous)

=head1 SYNOPSIS 

	use Net::Rendezvous;
	
	my $res = Net::Rendezvous->new(<service>[, <protocol>]);

	$res->discover;

	foreach my $entry ( $res->entries ) {
		printf "%s %s:%s\n", $entry->name, $entry->address, $entry->port;
	}

Or the cyclical way:

	use Net::Rendezvous;

	my $res = Net::Rendezvous->new(<service>[, <protocol>]);
               
	$res->discover;

	while ( 1 ) {
	   foreach my $entry ( $res->entries ) {
		   print $entry->name, "\n";
	   }
	   $res->discover;
   	}

=head1 DESCRIPTION

Net::Rendezvous is a set of modules that allow one to discover local services via multicast DNS (mDNS) 
or enterprise services via traditional DNS.  This method of service discovery has been branded as 
Rendezvous by Apple Computer.

=head2 Base Object

The base object would be of the Net::Rendezvous class.  This object contains the resolver for DNS service discovery.

=head2 Entry Object

The base object (Net::Rendezvous) will return entry objects of the class L<Net::Rendezvous::Entry>.

=head1 METHODS

=head2 new([<service>, <protocol>, <domain>])

Creates a new Net::Rendezvous discovery object.  First argument specifies the service to discover, 
e.g.  http, ftp, afpovertcp, and ssh.  The second argument specifies the protocol, i.e. tcp or udp.  
I<The default protocol is TCP>. The third argument specifies the discovery domain, the default is 'local'. 

If no argments are specified, the resulting Net::Rendezvous object will be empty and will not perform an 
automatic discovery upon creation.

=head2 domain([<domain>])

Get/sets current discovery domain.  By default, the discovery domain is 'local'.  Discovery for the 'local'
domain is done via MDNS while all other domains will be done via traditional DNS.

=head2 discover

Repeats the discovery process and reloads the entry list from this discovery.

=head2 entries

Returns an array of L<Net::Renedezvous::Entry> objects for the last discovery.

=head2 shift_entry

Shifts off the first entry of the last discovery.  The returned object will be a L<Net::Rendezvous::Entry> object.

=head1 EXAMPLES 

=head2 Print out a list of local websites

        print "<HTML><TITLE>Local Websites</TITLE>";
        
        use Net::Rendezvous;

        my $res = Net::Rendezvous->new('http');
	$res->discover;

        foreach my $entry ( $res->entries) {
                printf "<A HREF='http://%s%s'>%s</A><BR>", $entry->address, 
                        $entry->attribute('path'), $entry->name; 
        }
        
        print "</HTML>";

=head2 Find a service and connect to it

        use Socket;
	use Net::Rendezvous;
        
        my $res = Net::Rendezvous->new('custom');
	$res->discover;
        
        my $entry = $res->shift_entry;
        
        socket SOCK, PF_INET, SOCK_STREAM, scalar(getprotobyname('tcp'));
        
        connect SOCK, $entry->sockaddr;
        
        print SOCK "Send a message to the service";
        
        while ($line = <SOCK>) { print $line; }
        
        close SOCK;     

=head1 SEE ALSO

L<Net::Rendezvous::Entry>

=head1 COPYRIGHT

This library is free software and can be distributed or modified under the same terms as Perl itself.

Rendezvous (in this context) is a trademark of Apple Computer, Inc.

=head1 AUTHORS

The Net::Rendezvous module was created by George Chlipala <george@walnutcs.com>

=cut

use strict;
use vars qw($VERSION);

use Net::DNS;
use Net::Rendezvous::Entry;
use Socket;

$VERSION = '0.80';

sub new {
	my $self = {};
	bless $self, shift;
	$self->_init(@_);
	return $self;
}

sub _init {
	my $self = shift;

	$self->{'_dns_server'} = [ '224.0.0.251' ];
	$self->{'_dns_port'} = '5353';
	$self->{'_dns_domain'} = 'local';

	if (@_) {
		$self->domain(pop) if $_[$#_] =~ /\./;
		$self->application(@_);
		$self->discover;
	}
	return;
}
	
sub application {
	my $self = shift;

	if (@_) {
		my $app = shift;
		my $proto = shift || 'tcp';
		$self->{'_app'} = sprintf '_%s._%s.%s', $app, $proto, 
			$self->{'_dns_domain'};
	}

	return $self->{'_app'};
}

sub dns_refresh { 
	my $self = shift;
	
	my $resolv = Net::DNS::Resolver->new();
	
	my $query = $resolv->query($self->application, 'PTR');
	my $list = [];

	foreach my $rr ($query->answer) {
		next if $rr->type ne 'PTR';
		my $host = Net::Rendezvous::Entry->new($rr->ptrdname);
		$host->dns_server($resolv->nameservers);
		$host->dns_port($resolv->port);
		$host->fetch;
		push(@{$list}, $host);
	}

	$self->{'_results'} = $list;
	return $#{$list};
}

sub mdns_refresh {
	my $self = shift;

	my $query = Net::DNS::Packet->new($self->application, 'PTR');

	socket DNS, PF_INET, SOCK_DGRAM, scalar(getprotobyname('udp'));
	bind DNS, sockaddr_in(0,inet_aton('0.0.0.0'));
	send DNS, $query->data, 0, sockaddr_in($self->{'_dns_port'}, inet_aton($self->{'_dns_server'}[0]));

	my $rout = '';
	my $rin  = '';
	my $list = [];

	vec($rin, fileno(DNS), 1) = 1;

	while (select($rout = $rin, undef, undef, 1.0)) {

		my $data;
		recv(DNS, $data, 1000, 0);

		my $ans = Net::DNS::Packet->new(\$data);
		next if $query->header->id != $ans->header->id;

		foreach my $rr ($ans->answer) {
			next if $rr->type ne 'PTR';
			my $host = Net::Rendezvous::Entry->new($rr->ptrdname);
			$host->dns_server($self->{'_dns_server'});
			$host->dns_port($self->{'_dns_port'});
			$host->fetch;
			push(@{$list}, $host);
		}
	}

	$self->{'_results'} = $list;
	return $#{$list};
}

sub entries {
	my $self = shift;	
	return @{$self->{'_results'}};
}

sub shift_entry {
	my $self = shift;
	return shift(@{$self->{'_results'}});
}

sub domain {
	my $self = shift;
	
	if ( @_ ) {
		$self->{'_dns_domain'} = shift;
		$self->{'_dns_domain'} =~ s/[(^\.)(\.$)]//;
	}
	return $self->{'_dns_domain'};
}

sub refresh { 
	my $self = shift;
	return $self->discover(@_);
}

sub discover {
	my $self = shift;

	if ( $self->domain(@_) eq 'local' ) {
		return $self->mdns_refresh;
	} else {
		return $self->dns_refresh;
	}

	return;
}
1;
