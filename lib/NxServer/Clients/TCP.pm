=head1 NAME

NxServer::Clients::TCP - TCP server for clients

=head1 DESCRIPTION

=over

=cut

package NxServer::Clients::TCP;

use strict;
use Exporter;
use IO::Socket::INET;
use POSIX;
use NxGlobals;


=item NxServer::Clients::TCP->init($nxserver);

Initializes object and binds server to address:port. Expects pointer to
NxServer object.

=cut
sub new($$) {
	my $self={};
	bless($self,shift);
	$self->{'_nxserver'}=shift;

	# bind server to address:port
	my $tcpcfg=$self->nxconfig()->{'clients-tcp'};
	$self->{'server'}=IO::Socket::INET->new(
		Listen		=>	5,
		LocalAddr	=>	$tcpcfg->{'name'},
		LocalPort	=>	$tcpcfg->{'port'},
		Proto		=>	'tcp',
		Reuse		=>	1
	) || $self->finish();

	$self->{'_max_clients'}=$tcpcfg->{'max_clients'};

	# set non-blocking read
	$self->{'server'}->timeout(0);

	# debug: NxServer::Clients::TCP created
	$self->print_debug(5000);

	return($self);
}


=item NxServer::Clients::TCP->name();

Returns code name of this class (i.e. 'tcp').

=cut
sub name($) {
	my $self=shift;
	return 'tcp';
}


=item NxServer::Clients::TCP->max_clients();

Returns max_clients for this client type (taken from config).

=cut
sub max_clients($) {
	my $self=shift;
	return $self->{'_max_clients'};
}


=item NxServer::Clients::TCP->finish();

Dies because of unsuccessfull bind to address:port.

=cut
sub finish($) {
	my $self=shift;

	# failed to bind to addr/port
	my $tcpcfg=$self->nxconfig()->{'clients-tcp'};
	# dies here because of critical error
	$self->print_debug(-5001,$tcpcfg->{'name'}.':'.$tcpcfg->{'port'});
}


=item NxServer::Clients::TCP->get_new_client();

Tries to accept new connection if there is any. This is non blocking
operation - so we look and go further. Handle to accepted connection
is returned, otherwise undef.

=cut
sub get_new_client($) {
	my $self=shift;

	my $client=$self->{'server'}->accept();
	if (defined $client) {
		# remote address
		my $ip=$client->peerhost();
		my $hostname=gethostbyaddr($client->peeraddr(),AF_INET);

		# is this host allowed?
		if ($self->allowed_client($ip,$hostname)) {
			# log new connection
			$self->print_debug(5002,(defined $hostname?$hostname:$ip));

	        # print welcome message if needed
			my $welcome_msg=$self->nxconfig()->{'clients-tcp'}->{'welcome_msg'};
			print($client '+OK TEXT:'.$welcome_msg,"\n")
				if defined $welcome_msg && $welcome_msg!~/^\s*$/;

			return($client);
		} else {
			# close connection
			$client->close();

			# log refused connection
			$self->print_debug(-5003,(defined $hostname?$hostname:$ip));
		}
	}
	return;
}


=item NxServer::Clients::TCP->allowed_client($ip,$hostname);

Depending on configuration setting decides whether remote client
is allowed to connect NxServer server.

=cut
sub allowed_client($$$) {
	my ($self,
		$ip,
		$hostname
	) = @_;

	my @clients=split(/,/,$self->nxconfig()->{'clients-tcp'}->{'allow_from'});
	if (scalar(@clients)) {
		for my $client (@clients) {
			return(1) if ($client eq $ip) || ($client=~/^$hostname$/i);
		}
		return(0);
	} else {
		return(1);
	}
}


=item NxServer::Clients::TCP->auth_data();

Returns password from configuration needed to connect NxServer.

=cut
sub auth_data($) {
	my $self=shift;
	return($self->nxconfig()->{'clients-tcp'}->{'password'});
}

=item NxServer::Clients::TCP->nxserver();

Returns pointer to object NxServer.

=cut
sub nxserver($) {
	my $self=shift;
	return($self->{'_nxserver'});
}


=item NxServer::Clients::TCP->nxconfig();

Returns pointer to structure with configuration.

=cut
sub nxconfig($) {
	my $self=shift;
	return($self->nxserver()->nxconfig());
}


=item NxServer::Clients::TCP->print_debug($code,[$additional_text]);

Calls print_debug function of NxServer object.

=cut
sub print_debug {
	my $self=shift;
	return($self->nxserver()->print_debug(@_));
}


1;


=head1 AUTHOR

Vlastimil Holer (xholer@fi.muni.cz)

=cut
