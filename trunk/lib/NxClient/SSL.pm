=head1 NAME

NxClient::SSL - TCP/SSL connection class to NxServer

=head1 DESCRIPTION 

=over

=cut

package NxClient::SSL;

use strict;
use Exporter;
use IO::Socket;
use IO::Socket::SSL;
use POSIX;
use NxGlobals;


=item NxClient::SSL->init($nxclient,$host,$port);

Initializes object and opens SSL connection to NxServer. Mandatory parameters
are reference to NxClient object, network hostname or IP ($host) of NxServer
and $port of service.

=cut
sub new($$$$$) {
	my $self={};
	bless($self,shift);

	# params
	$self->{'_nxclient'}=shift;
	$self->{'_host'}=shift or $self->print_debug(-22001);
	$self->{'_port'}=shift or $self->print_debug(-22002);

	# connect to NxServer
	my $rtn=$self->{'_conn_socket'}=IO::Socket::SSL->new(
		PeerAddr	=> $self->{'_host'},
		PeerPort	=> $self->{'_port'},
		Proto		=> 'tcp'
	);

	# debug
	unless ($rtn) {
		$self->print_debug(-22003);
	} else {
		$self->print_debug(22004,$self->{'_host'}.':'.$self->{'_port'});
	}

	# debug: NxServer::Clients::SSL created
	$self->print_debug(22000);

	return($self);
}


=item NxClient::SSL->close();

Closes connection to NxServer.

=cut
sub close($) {
	my $self=shift;
	close($self->{'_conn_socket'});
}


=item NxClient::SSL->print_debug($code,[$additional_text]);

Calls print_debug function of NxServer object.

=cut
sub print_debug {
	my $self=shift;
	return($self->nxclient()->print_debug(@_));
}


=item NxClient::SSL->nxclient();

Returns reference to NxClient.

=cut
sub nxclient($) {
	my $self=shift;
	return($self->{'_nxclient'});
}


=item NxClient::SSL->conn_socket();

Returns connection socket.

=cut
sub conn_socket($) {
	my $self=shift;
	return($self->{'_conn_socket'});
}


1;


=head1 AUTHOR

Vlastimil Holer (xholer@fi.muni.cz)

=cut
