package Net::Rendezvous;

$VERSION = 0.5;

=head1 NAME

Net::Rendezvous - Module for mDNS service discovery (Apple's Rendezvous)

=head1 SYNOPSIS 

	use Net::Rendezvous;
	
	my $res = new Net::Rendezvous(<service>[, <protocol>]);

	foreach $entry ( $res->entries ) {
		printf "%s %s:%s\n", $entry->name, $entry->address,
			$entry->port;
		}

Or the cyclical way:

	use Net::Rendezvous;

	my $res = new Net::Rendezvous(<service>[, <protocol>]);
               
   while ( 1 ) {
		   foreach $entry ( $res->entries ) {
				   print $entry->name, "\n";
		   }
		   $res->refresh;
   }

=head1 DESCRIPTION

Net::Rendezvous is a set of modules that allow one to discover local services via multicast DNS (mDNS).
This method of service discovery has been branded as Rendezvous by Apple Computer.

=head2 Base Object

The base object would be of the Net::Rendezvous class.  This object contains the resolver for mDNS service discovery.

=head2 Entry Object

The base object (Net::Rendezvous) will return entry objects of the class L<Net::Rendezvous::Entry>.

=head1 METHODS

=head2 new(<service>[, <protocol>])

Creates a new Net::Rendezvous discovery object.  First argument (required) specifies the service to discover, 
e.g.  http, ftp, afpovertcp, and ssh.  The second argument (optional) specifies the protocol, i.e. tcp or udp.  
I<The default protocol is TCP>.

=head2 refresh

Repeats the discovery process and reloads the entry list from this discovery.

=head2 entries

Returns an array of L<Net::Renedezvous::Entry> objects for the last discovery.

=head2 shift_entry

Shifts off the first entry of the last discovery.  The returned object will be a L<Net::Rendezvous::Entry> object.

=head1 EXAMPLES 

=head2 Print out a list of local websites

        print "<HTML><TITLE>Local Websites</TITLE>";
        
        use Net::Rendezvous;

        my $res = new Net::Rendezvous('http');

        foreach $entry ( $res->entries) {
                printf "<A HREF='http://%s%s'>%s</A><BR>", $entry->address, 
                        $entry->attribute('path'), $entry->name; 
        }
        
        print "</HTML>";

=head2 Find a service and connect to it

        use Socket;
		use Net::Rendezvous;
        
        my $res = new Net::Rendezvous('custom');
        
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

sub new {
	my $self = {};
	bless $self, shift;
	$self->_init(shift);
	return $self;
}

sub _init {
	my $self = shift;
	$self->application(shift);
	$self->{'_ns'} = '224.0.0.251';
	$self->{'_port'} = '5353';
	$self->refresh;
	return;
}
	
sub application {
	my $self = shift;
	if ( @_) {
		my $app = shift;
		my $proto = shift || 'tcp';
		$self->{'_app'} = sprintf '_%s._%s.local', $app, $proto;
	} else {
		return $self->{'_app'};
	}
	return;
}

sub refresh {
	my $self = shift;
	use Net::DNS;
	use Socket;
	use Net::Rendezvous::Entry;

	my $query = new Net::DNS::Packet($self->application, 'PTR');

	socket DNS, PF_INET, SOCK_DGRAM, scalar(getprotobyname('udp'));
	bind DNS, sockaddr_in(0,inet_aton('0.0.0.0'));
	send DNS, $query->data, 0, sockaddr_in($self->{'_port'}, inet_aton($self->{'_ns'}));

	my $rin = ''; my $list = [];
	vec($rin, fileno(DNS), 1) = 1;

	while ( select($rout = $rin, undef, undef, 1.0)) {
		my $data, $rr;
		recv(DNS, $data, 1000, 0);
		my $ans = new Net::DNS::Packet( \$data );
		foreach $rr ( $ans->answer ) {
			my $host = new Net::Rendezvous::Entry($rr->rdatastr);
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
