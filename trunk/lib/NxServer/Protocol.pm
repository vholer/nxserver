=head1 NAME

NxServer::Protocol - Netlinx XML protocol implementation

=head1 DESCRIPTION

=over

=cut

package NxServer::Protocol;

use strict;
use Exporter;
use XML::Mini::Document;
use NxServer::Storage;


=item NxServer::Protocol->new($nxserver);

Creates new Netlinx protocol object.

=cut
sub new($$) {
	my $self={};
	bless($self,shift);
	$self->{'_nxserver'}=shift;

	$self->init_structures;

	# Protocol created
	$self->print_debug(3000);
	return($self);
}


=item NxServer::Protocol->init_structures;

Inits internal structures.

=cut
sub init_structures($) {
	my $self=shift;

	# initial Netlinx address
	$self->{'_nx_adr'} = {
		'device'	=>	0,
		'port'		=>	1,
		'system'	=>	0
	};

	# this client initial address
	$self->{'_my_adr'} = {
		'device'			=>	0,
		'port'				=>	1,
		'system'			=>	0,
		'deviceLow'			=>	$self->nxconfig()->{'id'}->{'device_low'},
		'deviceHigh'		=>	$self->nxconfig()->{'id'}->{'device_high'},
		'identification'	=>	$self->nxconfig()->{'id'}->{'name'},
		'count'				=>	$self->nxconfig()->{'id'}->{'count'},
	};

	# version info
	$self->{'_ver_major'}=1;
	$self->{'_ver_minor'}=1;
	# message ID (incremented after every message) -- local/remote
	$self->{'_lc_msgID'}=0;
	$self->{'_rt_msgID'}=0;
	# timeout?
	$self->{'_timeout'}=0;
	# session ID
	$self->{'_sessionID'} = undef;

	# structure saving msgID of GetMessage sent and received
	# to/from Netlinx; there are only unconfirmed msgs
	#
	# {
	#    $msgID => { system=>?? , device=?? , port=?? },
	#    $msgID => { system=>?? , device=?? , port=?? }
	# }
	$self->{'_sent_getMessage'}={};
	$self->{'_rcvd_getMessage'}={};

	# init storage data
	$self->nxstorage()->init_structures;
}


=item NxServer::Protocol->build_message(bleeee);

List of known XML tags in messages is:

<?xml version="1.0"?>
<root>
    <SessionID>
    <messageGroup>
        <defRouting>
            <dst>
                <dev>
                    <system>
                    <device>
                    <port>
            <src>
                <dev>
                    <system>
                    <device>
                    <port>

        <messageList>
            <message>
                <messageHeader>
                    <flags>
                    <dst>
                        <dev>
                            <system>
                            <device>
                            <port>
                    <src>
                        <dev>
                            <system>
                            <device>
                            <port>
                    <msgID>
                    <msgCmd>

                <messageBody>
                    <dev>
                        <system>
                        <device>
                        <port>
                    <ValueType>
                    <Length>
                    <Data>
                    <Channel>
                    <Client>
                    <version>
                        <major>
                        <minor>
                    <timeout>
                    <devRequestList>
                        <devRequest>
                            <system>
                            <deviceLow>
                            <deviceHigh>
                            <count>
                    <devAllocationList>
                        <system>
                        <deviceFirst>
                        <count>
                    <version>
                    <status>

=cut
sub build_message {
	my ($self,
		$client_id,
		$msgCmd,
		$message
	) = @_;

	# create new document
	my $doc=XML::Mini::Document->new();

	## doplneni tela zpravy o zdroj
	#$$message{'dev'}	=	{
	#	'system'	=>	$self->{'_my_adr'}->{'system'},
	#	'device'	=>	$self->{'_my_adr'}->{'device'},
	#	'port'		=>	$self->{'_my_adr'}->{'port'}+($client_id-1)
	#};

	# generate message hash
	my $doc_hash = {
		'root' => {
			## ID sezeni
			'SessionID' => (defined $self->{'_sessionID'}?$self->{'_sessionID'}:{}),
			## obal zpravy
			'messageGroup' => {
				## message list
				'messageList' => {
					## message
					'message' => {
						## message header
						'messageHeader'	=>	{
							## flags
							'flags'	=>	{},
							## destination - system, device, port
							'dst'	=>	{
								'system'	=>	$self->{'_nx_adr'}->{'system'},
								'device'	=>	$self->{'_nx_adr'}->{'device'},
								'port'		=>	$self->{'_nx_adr'}->{'port'}
							},
							## source - system, device, port
							'src'	=>	{
								'system'	=>	$self->{'_my_adr'}->{'system'},
								'device'	=>	$self->{'_my_adr'}->{'device'}+($client_id-1),
								'port'		=>	$self->{'_my_adr'}->{'port'}
							},
							## message ID - pro kazdou zpravu o jednicku vetsi
							'msgID'		=>	$self->{'_lc_msgID'}++,
							## message Command - povel Masterovi
							'msgCmd'	=>	$msgCmd
						},
	
						## message body
						'messageBody'	=> {
							'dev'		=>	{
								'system'	=>	$self->{'_my_adr'}->{'system'},
								'device'	=>	$self->{'_my_adr'}->{'device'}+($client_id-1),
								'port'		=>	$self->{'_my_adr'}->{'port'}
							},
							%$message
						}
					}
				}
			}
		}
	};

	# because of overflow
	$self->{'_lc_msgID'}%=65535
		if $self->{'_lc_msgID'}>65535;

	# convert hash to object internal structures
	$doc->fromHash($doc_hash);
	my $xml_str=$doc->toString(); $xml_str=~s/[ \n]//g;
	return('<?xml version="1.0"?>'.$xml_str."\n"); # '\n' because of my zsh simulator
}



=item NxServer::Protocol->build_message_login;

Build XML message: login.

=cut
sub build_message_login($) {
	my $self=shift;

	return $self->build_message(
		1,			## pocatecni ID zarizeni
		'Login',	## prikaz
		{
			'Client'	=>	$self->{'_my_adr'}->{'identification'},
			'version'	=>	{
				'major'	=>	$self->{'_ver_major'},
				'minor'	=>	$self->{'_ver_minor'}
			},
			'timeout'	=>	$self->{'_timeout'},
			'devRequestList'	=>	{
				'devRequest'	=>	{
					'system'		=>	$self->{'_my_adr'}->{'system'},
					'deviceLow'		=>	$self->{'_my_adr'}->{'deviceLow'},
					'deviceHigh'	=>	$self->{'_my_adr'}->{'deviceHigh'},
					'count'			=>	$self->{'_my_adr'}->{'count'}
				}
			}
		}
	);
}




=item NxServer::Protocol->build_message_getmessages($client_id);

Build XML message: GetMessages command from $client_id.

=cut
sub build_message_getmessages($$) {
	my ($self,
		$client_id
	) = @_;

	# save msgID of sent message
	$self->{'_sent_getMessage'}->{$self->{'_lc_msgID'}}={
		'system'	=>	$self->{'_my_adr'}->{'system'},
		'device'	=>	$self->{'_my_adr'}->{'device'}+($client_id-1),
		'port'		=>	$self->{'_my_adr'}->{'port'},
		'timestamp'	=>	time(),
		'confirmed'	=>	0
	};

	return $self->build_message(
		$client_id,
		'GetMessages',
		{}
	);
}



=item NxServer::Protocol->build_message_rgetmessages($client_id);

Build XML message: reply to GetMessages command from $client_id.

=cut
sub build_message_rgetmessages($$) {
	my ($self,
		$client_id
	) = @_;

	return $self->build_message(
		$client_id,
		'rGetMessages',
		{}
	);
}



=item NxServer::Protocol->build_message_inputchannel_on($client_id,channel_id);

Build XML message: InputChannelOn from $client_id to $channel_id.

=cut
sub build_message_inputchannel_on($$$) {
	my ($self,
		$client_id,
		$channel_id
	) = @_;

	return $self->build_message(
		$client_id,
		'InputChannelOn',
		{ 'Channel'	=>	$channel_id }
	);
}



=item NxServer::Protocol->build_message_inputchanngel_off($client_id,$channel_id);

Build XML message: InputCHannelOff from $client_id to $channel_id.

=cut
sub build_message_inputchannel_off($$$) {
	my ($self,
		$client_id,
		$channel_id,
	) = @_;

	return $self->build_message(
		$client_id,
		'InputChannelOff',
		{ 'Channel'	=>	$channel_id }
	);
}




=item NxServer::Protocol->hash_get_item($hash,$path_array);

From tree ($hash) represented by reference to hash of hashes gets value from
path ($path_array).

=cut
sub hash_get_item($$$) {
	my ($self,
		$hash,
		$path
	) = @_;

	my $value=$hash;
	for my $x (@$path) {
		if (defined $value && ref $value eq 'HASH' && exists $$value{$x}) {
			$value=$$value{$x};
		} else {
			return;
		}
	}
	return($value);
}


=item NxServer::Protocol->check_remote_hash_msgID($pmessage);

Show difference between localy saved msgID and msgID got in
message from Netlinx. If everything is normal, we expect 1 (this means
that new message is greater by 1 than last one).

$pmessage is a hash message parsered by XML::Mini::Document and saved
to hash by XML::Mini::Document->toHash() function.

=cut
sub check_remote_hash_msgID($$) {
	my ($self,
		$pmessage
	) = @_;

	my $msgID=$self->hash_get_item($pmessage,['root','messageGroup',
			'messageList','message','messageHeader','msgID']);
	return $self->check_remote_msgID($msgID);
}


=item NxServer::Protocol->check_remote_hash_msgID($msgID);

The same as NxServer::Protocol->check_remote_hash_msgID except parameter
we get. This function accepts scalar variable $msgID with message number.
Returns difference between localy saved msgID and msgID got from Netlinx
in message header.

=cut
sub check_remote_msgID($$) {
	my ($self,
		$msgID
	) = @_;

	if (defined $msgID) {
		my $diff=$msgID-$self->{'_rt_msgID'};
		return $diff;
	} else {
		return undef;
	}
}


=item NxServer::Protocol->analyze_message($message);

Analyzes message received from Netlinx. From rLogin messages takes
allocation data. Stores Netlinx variables change (CommandSend,
OuputChannelOn/Off, LevelValueSet).

=cut
sub analyze_message($$) {
	my ($self,
		$message
	) = @_;

	# print input message
	$self->print_debug(1011,$message);

	if ($self->is_xmlmsg($message)) {
		# parser XML message, save it to hash for better manipulation
		my $parserXML=XML::Mini::Document->new();
		$parserXML->parse($message);
		my $pmessage=$parserXML->toHash(); #parsered message

		# print formated input message
		$self->print_debug(1014,$parserXML->toString());

		# test count of present messages
		my $messages=$self->hash_get_item($pmessage,['root',
			'messageGroup','messageList','message']);
		$self->print_debug(-3010)
			unless ref $messages eq 'HASH';


		# get command
		my $cmd  =$self->msgitem_msgcmd($pmessage);
		my $msgID=$self->msgitem_msgid($pmessage);


		# check msgID
		my $msgID_diff=$self->check_remote_hash_msgID($pmessage);

		if (($cmd eq 'rLogin') || ($cmd eq 'rGetMessages')) {

		} elsif (($msgID_diff == 0) || ($self->{'_rt_msgID'} == 0)) {
			$self->print_debug(3012);
			$self->{'_rt_msgID'}=$msgID+1;
			$self->{'_rt_msgID'}%=65535
				if $self->{'_rt_msgID'}>65535;
		} else {
			$self->print_debug(
				-3011,
				sprintf("%i/%i",$msgID,$self->{'_rt_msgID'})
			);
		}

		# reply to Login command -- important info. whith our address
		if ($cmd eq 'rLogin') {
			my $allocation_date=$self->hash_get_item($pmessage,['root',
				'messageGroup','messageList','message','messageBody',
				'devAllocationList','devAllocation']);

			# first case - we get all in message
			if (defined $allocation_date && ref $allocation_date eq 'HASH') {
				# assigned System and Device number
				$self->{'_my_adr'}->{'system'}=$self->hash_get_item($pmessage,['root','messageGroup',
					'messageList','message','messageBody','devAllocationList',
					'devAllocation','system']);
				$self->{'_my_adr'}->{'device'}=$self->hash_get_item($pmessage,['root','messageGroup',
					'messageList','message','messageBody','devAllocationList',
					'devAllocation','deviceFirst']);

				# store remote System, Device and Port
				$self->{'_nx_adr'}->{'system'}=$self->hash_get_item($pmessage,['root','messageGroup',
					'defRouting','src','dev','system']);
				$self->{'_nx_adr'}->{'device'}=$self->hash_get_item($pmessage,['root','messageGroup',
					'defRouting','src','dev','device']);
				$self->{'_nx_adr'}->{'port'}=$self->hash_get_item($pmessage,['root','messageGroup',
					'defRouting','src','dev','port']);

				# is allocated count of devices equal to requested?
				my $allocated_count=$self->hash_get_item($pmessage,['root','messageGroup',
					'messageList','message','messageBody','devAllocationList',
					'devAllocation','count']);
				$self->print_debug(-3001)
					unless $allocated_count==$self->{'_my_adr'}->{'count'};

			# second case - we didn't get dev allocation -> EXIT
			} else {
				$self->print_debug(-3005);
			}

			$self->{'_sessionID'}=$self->hash_get_item($pmessage,['root','SessionID']);

			# is msgID from rLogin eq to 0 (??)
			$self->print_debug(-3002,sprintf("%s:%i/%i",$cmd,$msgID,0))
				if $msgID!=0;

		} else {
			# check for which device is message
			my $dev_order=$self->dps2order($self->msgitem_bodydest($pmessage));
			$self->print_debug(-3008,$dev_order)
				unless $dev_order<=$self->my_adr->{'count'};

			if ($cmd eq 'rGetMessages') {
				# check previous GetMessages command
				my $msgID=$self->hash_get_item($pmessage,['root','messageGroup',
					'messageList','message','messageHeader','msgID']);
				if (exists $self->{'_sent_getMessage'}->{$msgID}) {
					delete($self->{'_sent_getMessage'}->{$msgID});
				} else {
					$self->print_debug(-3009);
				}

			} elsif ($cmd eq 'CommandSend') {
				my @data=$self->msgitem_textdata($pmessage);
				$self->nxstorage->set_variabletext_channel(
					$dev_order, @data
				) if scalar(@data);

			} elsif ($cmd eq 'OutputChannelOn' || $cmd eq 'OutputChannelOff') {
				$self->nxstorage()->set_push_channel(
					$dev_order, $self->msgitem_channel($pmessage),
					($cmd eq 'OutputChannelOn'?1:0)
				);

			} elsif ($cmd eq 'LevelValueSet') {
				$self->nxstorage()->set_level_channel(
					$dev_order,
					$self->msgitem_leveldata($pmessage)
				);
			};
		}

		# return analyzed message
		return($pmessage);
	}
}



=item NxServer::Protocol->msgitem_msgcmd($parsered_message);

Returns message command item from parsered XML message.

=cut
sub msgitem_msgcmd($$) {
	my ($self,
		$pmessage
	) = @_;
	
	return(
		$self->hash_get_item($pmessage,['root','messageGroup',
		'messageList','message','messageHeader','msgCmd'])
	);
}



=item NxServer::Protocol->msgitem_msgid($parsered_message);

Returns message ID item from parsered XML message.

=cut
sub msgitem_msgid($$) {
	my ($self,
		$pmessage
	) = @_;
	
	return(
		$self->hash_get_item($pmessage,['root','messageGroup',
		'messageList','message','messageHeader','msgID'])
	);
}



=item NxServer::Protocol->msgitem_channel($parsered_message);

Returns Channel item from parsered OutputChannel(On|Off) message.

=cut
sub msgitem_channel($$) {
	my ($self,
		$pmessage
	) = @_;
	
	return(
		$self->hash_get_item($pmessage,['root','messageGroup',
		'messageList','message','messageBody','Channel'])
	);
}




=item NxServer::Protocol->msgitem_bodydest($parsered_message);

Returns array of 3 items - system, device, port - got from parsered
message's body (i.e. from <dev> section in <messageBody>)

=cut
sub msgitem_bodydest($$) {
	my ($self,
		$pmessage
	) = @_;

	my $device=$self->hash_get_item($pmessage,['root','messageGroup',
		'messageList','message','messageBody','dev','device']);
	my $system=$self->hash_get_item($pmessage,['root','messageGroup',
		'messageList','message','messageBody','dev','system']);
	my $port  =$self->hash_get_item($pmessage,['root','messageGroup',
		'messageList','message','messageBody','dev','port']);

	return(($device,$port,$system))
		if defined $system && defined $device && defined $port;
}


=item NxServer::Protocol->msgitem_leveldata($parsered_message);

Returns data about Level from LevelValueSet message.

=cut
sub msgitem_leveldata($$) {
	my ($self,
		$pmessage
	) = @_;

	my $level =$self->hash_get_item($pmessage,['root','messageGroup',
		'messageList','message','messageBody','Level']);
	my $value =$self->hash_get_item($pmessage,['root','messageGroup',
		'messageList','message','messageBody','Value']);
	my $valuet=$self->hash_get_item($pmessage,['root','messageGroup',
		'messageList','message','messageBody','ValueType']);
	my $lngth =$self->hash_get_item($pmessage,['root','messageGroup',
		'messageList','message','messageBody','Length']);

	# type conversion and check if length is as expected
	$value=$self->decode_value($value,$valuet);
	$self->print_debug(-3007) if defined $lngth && length($value)!=$lngth;

	return(($level,$value,$valuet))
		if defined $level && defined $value;
}


=item NxServer::Protocol->msgitem_textdata($parsered_message);

Returns text data from message.

=cut
sub msgitem_textdata($$) {
	my ($self,
		$pmessage
	) = @_;

	my $value =$self->hash_get_item($pmessage,['root','messageGroup',
		'messageList','message','messageBody','Data']);
	my $valuet=$self->hash_get_item($pmessage,['root','messageGroup',
		'messageList','message','messageBody','ValueType']);
	my $lngth =$self->hash_get_item($pmessage,['root','messageGroup',
		'messageList','message','messageBody','Length']);

	# type conversion and check if length is as expected
	$value=$self->decode_value($value,$valuet);
	$self->print_debug(-3007) if defined $lngth && length($value)!=$lngth;

	# return data only if !T text pressent
	if ($value=~/^!T(.)(.*)$/) {
		my $port=ord($1);
		return(($port,$2,$valuet))
			if defined $port;
	} else {
		return;
	}
}


=item NxServer::Protocol->message_present($queue);

Returns 1 wheather there are any messages in queue. 0 otherwise.

=cut
sub message_present($$) {
    my ($self,
		$queue
	) = @_;

	# split queue with in </root>
	my @messages=split(/<\/root>/,$queue,2);

	# analyze 
	if (scalar(@messages)>1) {
		return(1);
	} elsif (scalar(@messages)==1 && $self->is_xmlmsg($queue)) {
		return(1);
	} else {
		return(0);
	}
}


=item NxServer::Protocol->garbage_out($queue);

Removes leading garbage from input message queue.

=cut
sub garbage_out($$) {
	my ($self,
		$queue
	) = @_;

	$$queue=$1 if $$queue=~/^.{1,30}(<\?xml version.*)$/;
}


=item NxServer::Protocol->pop_message($queue,$pop);

Returns first XML message and deletes it from queue if $pop is positive.
$queue is pointer to queue.

=cut
sub get_message($$$) {
    my ($self,
		$queue,
		$pop
	) = @_;

	# split queue with in </root>
	my @messages=split(/<\/root>/,$$queue,2);

	# analyze 
	if (scalar(@messages)>1) {
		if($pop) {
			$$queue=$messages[1] ;
			$$queue=~s/^\s//; # this is useless I hope
		}
		return($messages[0].'</root>');
	} elsif (scalar(@messages)==1 && $self->is_xmlmsg($$queue)) {
		$$queue='' if $pop;
		return($messages[0].'</root>');
	} else {
		return;
	}
}


=item NxServer::Protocol->is_xmlmsg($message);

Returns 1 if $message looks like XML message. Otherwise 0.

=cut
sub is_xmlmsg($$) {
	my ($self,
		$message
	) = @_;

	return(($message=~/^\<\?xml.*\<\/root\>$/i?1:0));
}


=item NxServer::Protocol->is_datacmd($command);

Checks whether message is data command.

=cut
sub is_datacmd($$) {
	my ($self,
		$command
	) = @_;

	return unless defined $command;
	return 1 if
		$command eq 'CommandSend' ||
		$command eq 'OutputChannelOn' ||
		$command eq 'OutputChannelOff' ||
		$command eq 'LevelValueSet';
}


=item NxServer::Protocol->nx_adr();

Returns pointer to HASH with address of remote NetLinx. Hash elements
are: device, port and system

=cut
sub nx_adr($) {
	my $self=shift;
	return($self->{'_nx_adr'});
}


=item NxServer::Protocol->my_adr();

Returns pointer to HASH with address of local NetLinx client. Relevant
hash elements are: device, port, system and count

=cut
sub my_adr($) {
	my $self=shift;
	return($self->{'_my_adr'});
}


=item NxServer::Protocol->my_adr_order($device_order);

Returns pointer to HASH with address of local NetLinx client with
$device_order. Hash elements are: device, port and system

=cut
sub my_adr_order($$) {
	my ($self,	
		$device_order
	) = @_;

	return({
		$self->{'_my_adr'}->{'device'}+$device_order-1,
		$self->{'_my_adr'}->{'port'},
		$self->{'_my_adr'}->{'system'}
	});
}



=item NxServer::Protocol->hash_adr2array_adr($hash_address);

Address stored in HASH $hash_address with elements device, port and
system returns as ARRAY with theses datas.

=cut
sub hash_adr2array_adr($$) {
	my ($self,
		$hash_addr
	) = @_;

	return((
		$hash_addr->{'device'},
		$hash_addr->{'port'},
		$hash_addr->{'system'}
	));
}


=item NxServer::Protocol->dps2order($device);

Returns order of device. Device can ben numbered e.g. 10000 .. 10005 and
this function returns for device 10002 number 3 (3rd).

=cut
sub dps2order {
	my ($self,
		$device
	) = @_;
		
	return($device-$self->{'_my_adr'}->{'device'}+1);
}




=item NxServer::Protocol->decode_value($value,$value_type);

Returns $value as expected type of value ($value_type).
Some values must be decoded (e.g. text).

=cut
sub decode_value($$$) {
	my ($self,
		$value,
		$value_type
	) = @_;

	# variable is BYTE
	if ($value_type=~/^BYTE$/i) {
		return($value);

	# variable is STRING - must be decoded
	} elsif ($value_type=~/^CHARSTRING$/i) {
		my $rtn='';
		while($value=~s/^(..)//) {
			$rtn.=chr hex $1;
        }
		return($rtn);

	# uknnown variable ;-(
	} else {
		$self->print_debug(-3004,$value_type);
	}
}


=item NxServer::Protocol->nxserver();

Returns pointer to object NxServer.

=cut
sub nxserver($) {
	my $self=shift;
	return($self->{'_nxserver'});
}


=item NxServer::Protocol->nxconfig();

Returns pointer to structure with configuration.

=cut
sub nxconfig($) {
	my $self=shift;
	return($self->nxserver()->nxconfig());
}


=item NxServer::Protocol->nxstorage();

Returns pointer to object NxServer::Storage.

=cut
sub nxstorage($) {
	my $self=shift;
	return($self->nxserver()->nxstorage());
}


=item NxServer::Protocol->print_debug($code,[$additional_text]);

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
