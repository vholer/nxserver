=head1 NAME

NxServer::Clients - Client connection servers

=head1 DESCRIPTION

=over

=cut

package NxServer::Clients;

use strict;
use Exporter;
use IO::Socket;
use POSIX;
use NxGlobals;
use NxServer::Clients::TCP;
use NxServer::Clients::SSL;
use Socket qw(:DEFAULT :crlf);
use Time::HiRes qw( usleep );


=item NxServer::Clients->init($nxserver);

Initializes object, expects pointer to NxServer object. According to
configuration creates TCP and/or TCP/SSL client connection server.

=cut
sub new($$) {
	my $self={};
	bless($self,shift);
	$self->{'_nxserver'}=shift;

	# client types
	$self->{'_client_types'}=();

	if ($self->nxconfig()->{'clients-tcp'}->{'enabled'}) {
		push(
			@{$self->{'_client_types'}},
			NxServer::Clients::TCP->new($self->nxserver())
		);
	}

	if ($self->nxconfig()->{'clients-tcpssl'}->{'enabled'}) {
		push(
			@{$self->{'_client_types'}},
			NxServer::Clients::SSL->new($self->nxserver())
		);
	}

	# there are no Client subobjects
	$self->print_debug(-4001)
		if scalar(@{$self->{'_client_types'}})==0;

	# NxServer::Clients created
	$self->print_debug(4000);
	return($self);
}


=item NxServer::Clients->poll();

Polls new possible client connections and processes existing connections.

=cut
sub poll($) {
	my $self=shift;

	for my $clientt (@{$self->{'_client_types'}}) {
		$self->poll_client_type($clientt);
		$self->poll_client_pipes($clientt);
	}
}


=item NxServer::Clients->poll_client_type($client_type_object);

Ask specific type of listening server (TCP or SSL) for new available connection.
Exits if there is none. Otherwise accepts connection, creates IPC pipes and
forks process. Child process is processing client requests and passes them to
parent process through pipe. Parent process after fork exits method.

=cut
sub poll_client_type($$) {
	my ($self,
		$clientt
	) = @_;

	if (my $client=$clientt->get_new_client()) {
		if (scalar(keys %{$self->{$clientt->name}->{'_reading_pipes'}})<
			$clientt->max_clients)
		{
			# init IPC for new client
			pipe(P_RDR, C_WTR);
			pipe(C_RDR, P_WTR);

			if (defined *P_RDR && defined *P_WTR && defined *C_RDR && defined *C_WTR) {
				$self->print_debug(4005);
			} else {
				$self->print_debug(-4004);
			}

			# pipes settings
			C_WTR->autoflush(1);
			P_WTR->autoflush(1);
			fcntl(P_RDR, F_SETFL(), O_NONBLOCK());
			fcntl(P_WTR, F_SETFL(), O_NONBLOCK());
	
			# fork
			my $forked=fork();
			if (defined $forked and $forked==0) {
				# *child process*
				$self->do_auth($client,$clientt->auth_data()) &&
					$self->process_client($client,*C_RDR,*C_WTR);
				close($client);
				exit; 
			} elsif (defined $forked) {
				# *parent process*
				$self->print_debug(4002,$forked);
				# store pipes
				$self->{$clientt->name}->{'_reading_pipes'}->{$forked}=*P_RDR;
				$self->{$clientt->name}->{'_writing_pipes'}->{$forked}=*P_WTR;
			} else {
				# unsuccessfull fork
				$self->print_debug(-4003);
			}

		} else {
			print($client "-ERR TEXT: Max. clients exceeded\n");
		}
	}
}


=item NxServer::Clients->poll_client_pipes($client_type_object);

Read message from child (client connection) processes through pipes.
If there is any message, reads it, process request and sends back
reply.

=cut
sub poll_client_pipes($$) {
	my ($self,
		$clientt
	) = @_;

	# poll pipes
	for my $pid (keys %{$self->{$clientt->name}->{'_reading_pipes'}}) {
		# check existence of child process
		if ($self->opened_pipes($clientt,$pid)) {
			# read request from child
			my $handle=$self->{$clientt->name}->{'_reading_pipes'}->{$pid};
			my $request=<$handle>;

			# is there any message from subprocess?
			if (defined $request) {
				my $rtn=$self->process_child_request($request);

				# send our reply to subprocess
				if (defined $rtn) {
					my $handle=$self->{$clientt->name}->{'_writing_pipes'}->{$pid};
					print($handle $rtn,"\n");
				}
			}
		}
	}
}


=item NxServer::Clients->opened_pipes($client_type_object,$pid);

Determines whether client process with $pid still exists. We delete IPC
pipes of that process if not. Type of client ($client_type_object) must
be specified.

=cut
sub opened_pipes($) {
	my ($self,
		$clientt,
		$pid
	) = @_;

	if (waitpid($pid,WNOHANG)<0) {
		# close pipes
		delete($self->{$clientt->name}->{'_reading_pipes'}->{$pid});
		delete($self->{$clientt->name}->{'_writing_pipes'}->{$pid});
		$self->print_debug(4006,$pid);

		# closed pipes
		return 0;
	} else {
		return 1;
	}
}


=item NxServer::Clients->process_child_request($request);

Processes request from child process.

=cut
sub process_child_request($$) {
	my ($self,
		$request
	) = @_;

	chomp($request);
	if ($request=~/^setchannel\s+(on|off|pulse)\s+(\d+)\s+(\d+)$/i) {
		my $state  =$1;
		my $device =$2;
		my $channel=$3;

		if ($state=~/on/i) {
			$self->push_message_inputchannel($device,$channel,1);
			return('+OK');
		} elsif ($state=~/off/i) {
			$self->push_message_inputchannel($device,$channel,0);
			return('+OK');
		} else {
			# pulse: ON channel, pulse delay, OFF channel
			$self->push_message_inputchannel($device,$channel,1);
			$self->push_message_nop;
			$self->push_message_inputchannel($device,$channel,0);
			return('+OK');
		}

	} elsif ($request=~/^getchannel\s+push\s+(\d+)\s+(\d+)$/i) {
		my $data=$self->nxstorage()->get_push_channel($1,$2);
		if ($data) {
			return('+OK DATA:'.$self->nxstorage()->push_data2str($data));
		} else {
			return('-ERR DATA:uknown');
		}

	} elsif ($request=~/^getchannel\s+level\s+(\d+)\s+(\d+)$/i) {
		my $data=$self->nxstorage()->get_level_channel($1,$2);
		if ($data) {
			return('+OK DATA:'.$self->nxstorage()->level_data2str($data));
		} else {
			return('-ERR DATA:unknown');
		}

	} elsif ($request=~/^getchannel\s+text\s+(\d+)\s+(\d+)$/i) {
		my $data=$self->nxstorage()->get_variabletext_channel($1,$2);
		if ($data) {
			return('+OK DATA:'.$self->nxstorage()->text_data2str($data));
		} else {
			return('-ERR DATA:unknown');
		}

	} else {
		$self->print_debug(-4008);
	}
}


=item NxServer::Clients->push_message_inputchannel($device,$channel,$state);

Message InputChannel On or Off (according to $state) is enqueued to
outgoing message queue to Netlinx.

=cut
sub push_message_inputchannel($$$$) {
	my ($self,
		$device,
		$channel,
		$state
	) = @_;

	push(@{$self->nxpoll->{'message_queue'}},{
		cmd		=>'InputChannel'.($state?'On':'Off'),
		device	=>$device,
		channel	=>$channel
	});
}


=item NxServer::Clients->push_message_nop;

No-operation message is enqueued to outgoing message queue.
This is only "virtual" message to provide delay beween
messages.

=cut
sub push_message_nop($) {
	my $self=shift;

	push(@{$self->nxpoll->{'message_queue'}},{
		cmd		=>'Nop'
	});
}


=item NxServer::Clients->do_auth($client_handle,$password);

Do client authentication (e.g. with NxClient).

=cut
sub do_auth($$$) {
	my ($self,
		$client,
		$password
	) = @_;

	if ($password=~/^\s*$/) {
		print($client "+OK AUTH:NO\n");
		return(1);
	} else {
		print($client "+OK AUTH:YES\n");
		my $got_password=<$client>; $got_password=~s/$CR?$LF$//;
		if ($got_password eq $password) {
			print($client "+OK AUTH\n");
			return 1;
		} else {
			print($client "-ERR AUTH\n");
			return 0;
		}
	}
}


=item NxServer::Clients->process_client($client,$pipe_read,$pipe_write);

Proces connected clients. Gets command and send results. This provides interactive
text connection to client.

=cut
sub process_client($$$$) {
	my ($self,
		$client,
		$pipe_read,
		$pipe_write
	) = @_;

	# little bill
	##VL: print($client '>');
	print($client "+OK READY\n");

	while(my $cmd=<$client>) {
		$cmd=~s/$CR?$LF$//;

		if ($cmd=~/^(help|\?)$/i) {
			$self->print_help($client);
		} elsif ($cmd=~/^(logout|exit|quit)$/i) {
			return;
		} elsif ($cmd=~/^now$/i) {
			$self->print_now($client);
		} elsif ($cmd=~/^setchannel\s+(on|off|pulse)\s+\d+\s+\d+$/i ||
			 $cmd=~/^getchannel\s+(push|level|text)\s+\d+\s+\d+$/i)
		{
			print($pipe_write $cmd);	
			my $rtn=<$pipe_read>;
			print($client $rtn);
		} else {
			print($client "-ERR TEXT: Unknown command\n");
		}

		# little bill
		##VL: print($client '>');
	}
}


=item NxServer::Clients->print_help($client);

Prints short HELP for using console to client.

=cut
sub print_help($$) {
	my ($self,
		$client
	) = @_;

	print($client <<EOF);
+OK TEXT: Print this text:
+OK TEXT: help
+OK TEXT:  ?
+OK TEXT: Exit current connection:
+OK TEXT:   logout
+OK TEXT:   exit
+OK TEXT:   quit
+OK TEXT: Print server's current date and time:
+OK TEXT:   now
+OK TEXT: Set input channel to ON, OFF or PULSE:
+OK TEXT:   setchannel on    <device order> <channel>
+OK TEXT:   setchannel off   <device order> <channel>
+OK TEXT:   setchannel pulse <device order> <channel>
+OK TEXT: Get push channel status:
+OK TEXT:   getchannel push <device order> <level>
+OK TEXT: Get level channel status:
+OK TEXT:   getchannel level <device order> <channel>
+OK TEXT: Get text channel status:
+OK TEXT:   getchannel text <device order> <channel>
EOF
}


=item NxServer::Clients->print_now($client);

Prints current server's date and time to client.

=cut
sub print_now($$) {
	my ($self,
		$client
	) = @_;

	print($client '+OK DATA:'.strftime("%a %b %e %H:%M:%S %Y",localtime),"\n");
}


=item NxServer::Clients->nxserver();

Returns pointer to object NxServer.

=cut
sub nxserver($) {
	my $self=shift;
	return($self->{'_nxserver'});
}


=item NxServer::Clients->nxpoll();

Returns pointer to object NxServer::Poll.

=cut
sub nxpoll($) {
	my $self=shift;
	return($self->nxserver()->nxpoll());
}


=item NxServer::Clients->nxstorage();

Returns pointer to object NxServer::Storage.

=cut
sub nxstorage($) {
	my $self=shift;
	return($self->nxserver()->nxstorage());
}


=item NxServer::Clients->nxconfig();

Returns pointer to structure with configuration.

=cut
sub nxconfig($) {
	my $self=shift;
	return($self->nxserver()->nxconfig());
}


=item NxServer::Clients->print_debug($code,[$additional_text]);

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
