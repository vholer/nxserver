=head1 NAME

NxServer::Poll - Netlinx polling class

=head1 DESCRIPTION

=over

=cut

package NxServer::Poll;

use strict;
use Exporter;
use Carp qw(cluck confess);
use IO::Socket;
use POSIX;
use NxGlobals;
use NxServer::Protocol;


=item NxServer::Poll->new($nxserver);

Initializes new Netlinx polling class, its configuration and
connects to Netlinx.

=cut
sub new($$) {
	my $self={};
	bless($self,shift);
	$self->{'_nxserver'}=shift;

	# init everything
	return unless status_ok($self->init_config);
	return unless status_ok($self->init_nx);

	# Poll created
	$self->print_debug(1008);
	return($self);
}


=item NxServer::Poll->init_config;

Init polling automaton state and other internal variables.

=cut
sub init_config {
	my $self=shift;

	$self->{'_nxsocket'}=undef;
	$self->{'_nxprotocol'}=undef;
	$self->{'_automat_status'}=0;
	$self->{'_go_idle'}=-1;
	$self->{'_iqueue'}='';
	$self->{'_messages_devID'}=1;	# last deviceID sent GetMessages
	$self->{'_time_last_msg'}='';	# when last last message was sent/received
	$self->{'message_queue'}=[];

	# where connect to
	$self->{'_nxhost'}=$self->nxconfig()->{'netlinx'}->{'name'};
	$self->{'_nxport'}=$self->nxconfig()->{'netlinx'}->{'port'};
}


=item NxServer::Poll->init_nx;

Connects to Netlinx.

=cut
sub init_nx {
	my $self=shift;
	
	unless (defined($self->{'_nxsocket'})) {
		my $rtn=$self->{'_nxsocket'}=IO::Socket::INET->new(
			'PeerAddr' => $self->{'_nxhost'},
			'PeerPort' => $self->{'_nxport'}
		);

		# connected?
		unless($rtn) {
			# sorry, *no*; DIE
			$self->print_debug(-1001,$self->{'_nxhost'}.':'.$self->{'_nxport'});
		} else {
			# *yes
			fcntl($self->{'_nxsocket'}, F_SETFL(), O_NONBLOCK());
			# I moved creating of new protocol here from init_loop;
			# more actions from init_loop were done more times
			# $self->init_loop; 
			$self->{'_nxprotocol'}=NxServer::Protocol->new($self->nxserver());
			return($self->print_debug(1004,$self->{'_nxhost'}.':'.$self->{'_nxport'}));
		}
	} else {
		# already *connected*
		return($self->print_debug(-1000));
	}
}


=item NxServer::Poll->done_nx;

Disconnects from Netlinx.

=cut
sub done_nx {
	my $self=shift;
	
	# close socket
	close($self->{'_nxsocket'}) if
		defined($self->{'_nxsocket'});
	# destroy protocol
	$self->{'_nxprotocol'}=undef;
}


=item NxServer::Poll->init_loop;

Inits internal variables for new loop.

=cut
sub init_loop {
	my $self=shift;
	$self->{'_automat_status'}=0;
	$self->{'_nxprotocol'}=NxServer::Protocol->new($self->nxserver());
	$self->{'_iqueue'}='';
	$self->{'_messages_devID'}=1;	# last deviceID sent GetMessages
	$self->{'_time_last_msg'}='';	# when last last message was sent/received

	# process messages after connect
	for my $address (@{$self->nxserver->{'_pulse_on_connect'}}) {
    	push(@{$self->{'message_queue'}},(
		{
	        cmd     =>'InputChannelOn',
	        device  =>$address->{device},
	        channel =>$address->{channel}
	    },{
	        cmd     =>'Nop'
	    },{
	        cmd     =>'InputChannelOff',
	        device  =>$address->{device},
	        channel =>$address->{channel}
	    }));
	}
}


=item NxServer::Poll->poll;

Main automaton loop.

=cut
sub poll($) {
	my $self=shift;

	# write actual automaton state
	$self->print_debug(1009,$self->{'_automat_status'});

	# new message?
	my $nmessage=$self->{'_nxprotocol'}->message_present($self->{'_iqueue'});
	$self->{'_go_idle'}=-1 if $nmessage;

	# why Switch can't be used?:
	# Did not find leading dereferencer, detected at offset 2764syntax error at pl//NxServer/Poll.pm line 186, near ") {"
	# syntax error at pl//NxServer/Poll.pm line 188, near "}"
	
	if ($self->{'_automat_status'}==0) {
		# print_debug
		$self->print_debug(1012,$self->{'_iqueue'});

		$self->init_loop;	# init
		$self->{'_automat_status'}++;

	} elsif ($self->{'_automat_status'}==1) {
		$self->automaton1;	# Login	

	} elsif ($self->{'_automat_status'}==2 && $nmessage) {
		$self->automaton2;	# rLogin

	} elsif ($self->{'_automat_status'}==3) {
		## reset port num.
		$self->{'_messages_devID'}=1;
		$self->{'_automat_status'}++;

	} elsif ($self->{'_automat_status'}==4) {
		$self->automaton4;	# GetMessages
							# !!! predelat, tohle tak vubec byt nemusi....
							# muze rovnou dostavat zpravy aniz by o to zadal :-(((
							# pekne zpraseny protokol :(

	} elsif ($self->{'_automat_status'}==5 && $nmessage) {
		$self->automaton5;	# rGetMessages

	} elsif ($self->{'_automat_status'}==5 &&
		scalar(@{$self->{'message_queue'}}))
	{
		$self->automaton5messages;	# sendMessages

	} elsif ($self->{'_automat_status'}==5 &&
		time-$self->{'_time_sent_msg'}>=$self->nxconfig()->{'nxserver'}->{'get_message_delay'})
	{
		$self->print_debug(1021);
		$self->{'_automat_status'}=3;

	} else {
		$self->print_debug(-1007,$self->{'_automat_status'});
	} 

	# read data from Netlinx and save to input queue;
	# this read was moved to the end of method because
	# state 0 reseted input queue after receiving
	my $buf; recv($self->{'_nxsocket'},$buf,1000,0);
	if (defined $buf && length($buf)>0) {
		$self->{'_iqueue'}.=$buf;
		$self->{'_nxprotocol'}->garbage_out(\$self->{'_iqueue'});
		$self->{'_time_last_msg'}=time;
	} else {
		# it can be configured, that if go_idle exceeds value from configuration,
		# than comunication will be slower
		$self->{'_go_idle'}++;
	}
}



=item NxServer::Poll->automaton1;

Internal method -- represents automaton state 1 = sending Login command.

=cut
sub automaton1($) {
	my $self=shift;

	## << send Login  >>
	$self->send_msg($self->{'_nxprotocol'}->build_message_login());
	$self->{'_automat_status'}++;
}



=item NxServer::Poll->automaton2;

Internal method -- represents automaton state 2 = receiving
reply to Login command (ie rLogin).

=cut
sub automaton2($) {
	my $self=shift;

	## << wait for rLogin >>
	my $msg_in	=$self->{'_nxprotocol'}->get_message(\$self->{'_iqueue'},1);
	my $msg_cmd	=$self->{'_nxprotocol'}->msgitem_msgcmd(
		$self->{'_nxprotocol'}->analyze_message($msg_in)
	);

	if (defined $msg_cmd && $msg_cmd eq 'rLogin')  {
		$self->{'_automat_status'}++;
	} else {
		$self->print_debug(-1016,'rLogin/'.
			(defined $msg_cmd?$msg_cmd:'undefined'));
		$self->{'_automat_status'}=0;
	}
}



=item NxServer::Poll->automaton4;

Internal method -- represents automaton state 4 = send GetMessage
command from one source device.

=cut
sub automaton4($) {
	my $self=shift;

	##	<< send GetMessages from one device >>
	$self->send_msg(
		$self->{'_nxprotocol'}->build_message_getmessages(
			$self->{'_messages_devID'}
		)
	);

	$self->{'_automat_status'}++;
	$self->{'_messages_devID'}++;
}



=item NxServer::Poll->automaton5;

Internal method -- represents automaton state 5 = receiving
reply to GetMessages command (ie rGetMessages).

=cut
sub automaton5($) {
	my $self=shift;

	##	<< get rGetMessages for one device >>
	my $msg_in	=$self->{'_nxprotocol'}->get_message(\$self->{'_iqueue'},1);
	my $pmessage=$self->{'_nxprotocol'}->analyze_message($msg_in);
	my $msg_cmd	=$self->{'_nxprotocol'}->msgitem_msgcmd($pmessage);

	if (defined $msg_cmd) {
		if ($msg_cmd eq 'rGetMessages')  {
			$self->{'_automat_status'}=4
				if $self->{'_messages_devID'}<=$self->nxconfig()->
					{'id'}->{'count'};

		} elsif ($self->{'_nxprotocol'}->is_datacmd($msg_cmd)) {
			# print debug
			$self->print_debug(1013,$msg_cmd);

		} elsif ($msg_cmd eq 'GetMessages') {
			## << send rGetMessages  >>
			$self->send_msg(
				$self->{'_nxprotocol'}->build_message_rgetmessages(
					$self->{'_nxprotocol'}->dps2order(
						$self->{'_nxprotocol'}->hash_get_item($pmessage,['root',
							'messageGroup','messageList','message',
							'messageHeader','dst','dev','device']
						)
					)
				)
			);

		} else {
			$self->print_debug(-1019,$msg_cmd);
		}

	} else {
		# none command? very strange...
		$self->print_debug(-1020);
	}
}


=item NxServer::Poll->automaton5messages;

TODO:

=cut
sub automaton5messages($) {
	my $self=shift;

	# get new message
	my $message=shift(@{$self->{'message_queue'}});
	$self->print_debug(-1018)
		unless ref $message eq 'HASH';

	if ($message->{'cmd'} eq 'InputChannelOn') {
		$self->send_msg(
			$self->{'_nxprotocol'}->build_message_inputchannel_on(
				$message->{'device'},
				$message->{'channel'}
			)
		);
		
	} elsif ($message->{'cmd'} eq 'InputChannelOff') {
		$self->send_msg(
			$self->{'_nxprotocol'}->build_message_inputchannel_off(
				$message->{'device'},
				$message->{'channel'}
			)
		);

	} elsif ($message->{'cmd'} eq 'LevelValueSet') {
		$self->send_msg(
			$self->{'_nxprotocol'}->build_message_levelvalueset(
				$message->{'device'},
				$message->{'level'},
				uc($message->{'valuet'}),
				$message->{'value'}
			)
		);

	} elsif ($message->{'cmd'} eq 'Nop') {
		$self->print_debug(1022);

	} else {
		$self->print_debug(-1017,$message->{'cmd'});
	}
}




=item NxServer::Poll_>send_msg($message);

Send message to socket and print debug information.

=cut
sub send_msg($$) {
	my ($self,
		$message
	) = @_;

	# send to Netlinx
	send($self->{'_nxsocket'},$message,0);
	$self->{'_time_sent_msg'}=time;

	# print debug
	$self->print_debug(1010,$message);

	# print formated XML
	my $parserXML=XML::Mini::Document->new();
	$parserXML->parse($message);
	$self->print_debug(1015,$parserXML->toString());

	# we have sent message, fast poll from now
	$self->{'_go_idle'}=-1;
}


=item NxServer::Poll->nxserver();

Returns pointer to object NxServer.

=cut
sub nxserver($) {
    my $self=shift;
    return($self->{'_nxserver'});
}


=item NxServer::Poll->nxconfig();

Returns pointer to structure with configuration.

=cut
sub nxconfig($) {
    my $self=shift;
    return($self->nxserver()->nxconfig());
}



=item NxServer::Poll->go_idle();

Returns _go_idle internal variable.

=cut
sub go_idle($) {
	my $self=shift;
	return($self->{'_go_idle'});
}


=item NxServer::Poll->print_debug($code,[$additional_text]);

Calls print_debug function of NxServer object.

=cut
sub print_debug {
    my $self=shift;
    return($self->nxserver()->print_debug(@_));
}


1;


=head1 AUTHOR

Vlastimil Holer (holer@fi.muni.cz)

=cut
