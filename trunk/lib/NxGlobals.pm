=head1 NAME

NxGlobals - Global constants and functions

=head1 DESCRIPTION

=over

=cut

package NxGlobals;

use strict;
use Exporter;
our @ISA	= qw(Exporter);
our @EXPORT	= qw(get_config_content status_ok status_codes status_codes_belongs);


=item %codes

Hash with all possible output messages. Every hash element is reference to
another hash with more detailed information - text of message and message
debug level. Available debug levels are:

=over 8

=item 0

critical errors

=item 1

standard outs

=item 2

non-standard behaviour

=item 3

failed actions

=item 4

every action

=item 5

protocol data

=item 6

protocol debug

=back

=cut
my %codes=(
	# NxServer           (+-)     0 ..   999 
	     1 => {level=>1,msg=>'created'},
	     2 => {level=>4,msg=>'config file checked'},
	    -2 => {level=>0,msg=>'cannot read configuration'},
	    -3 => {level=>0,msg=>'incomplete configuration (%s)'},
		-4 => {level=>0,msg=>'bad address (in pulse_on_connect) in configuration: %s'},
	# NxServer::Poll     (+-)  1000 ..  1999
	  1002 => {level=>4,msg=>'polling subprocess forked'},
	  1004 => {level=>1,msg=>'connected to Netlinx (%s)'},
	  1008 => {level=>4,msg=>'created'},
	  1009 => {level=>4,msg=>'automat state %i'},
	  1010 => {level=>6,msg=>'sent    :%s'},
	  1011 => {level=>6,msg=>'received:%s'},
	  1012 => {level=>6,msg=>'reseting automat,structures,input queue (%s)'},
	  1013 => {level=>5,msg=>'got data message (%s)'},
	  1014 => {level=>6,msg=>"formated received\n%s"},
	  1015 => {level=>6,msg=>"formated sent\n%s"},
	  1021 => {level=>4,msg=>'time for new GetMessage round'},
	 -1000 => {level=>4,msg=>'already connected to Netlinx'},
	 -1001 => {level=>0,msg=>'Netlinx connect failed (%s)'},
	 -1003 => {level=>0,msg=>'cannot fork polling subprocess'},
	 -1005 => {level=>0,msg=>'initialization error'},
	 -1007 => {level=>2,msg=>'unhandled automat state (%s)'},
	 -1016 => {level=>6,msg=>'unexpected command (expected/got=%s)'},
	 -1017 => {level=>0,msg=>'unknown XML command received (%s)'},
	 -1018 => {level=>0,msg=>'internal message queue error - expected HASH'},
	 -1019 => {level=>0,msg=>'unknown XML command (%s), nothing expected'},
	 -1020 => {level=>0,msg=>'none XML command, nothing expected'},
	  1022 => {level=>6,msg=>'processing NOP command'},
	# NxServer::Storage  (+-)  2000 ..  2999
	  2000 => {level=>4,msg=>'created'},
	 -2001 => {level=>0,msg=>'no storage subobject created'},
	  2002 => {level=>4,msg=>'set channel'},
	  2003 => {level=>4,msg=>'get channel'},
	  2004 => {level=>4,msg=>'set level'},
	  2005 => {level=>4,msg=>'get level'},
	  2006 => {level=>4,msg=>'set variabletext'},
	  2007 => {level=>4,msg=>'get variabletext'},
	# NxServer::Protocol (+-)  3000 ..  3999	
	  3000 => {level=>4,msg=>'created'},
	 -3001 => {level=>6,msg=>'count of allocated devices not equal to requested'},
	 -3002 => {level=>6,msg=>'WARNING: got different msgID than expected (%s)'},
	 -3004 => {level=>0,msg=>'unknown value type (%s) in XML message'},
	 -3005 => {level=>0,msg=>'did not received dev allocation from Netlinx'},
	 -3006 => {level=>0,msg=>'received CommandSend without %s'},
	 -3007 => {level=>0,msg=>'received variable text with incorrect length'},
	 -3008 => {level=>0,msg=>'received message for device with order number %i, this is out of range!'},
	 -3009 => {level=>0,msg=>'confirmed unexisting or already confirmed message (ID %s)'},
	 -3010 => {level=>0,msg=>'received more than 1 messages in XML message'},
	 -3011 => {level=>1,msg=>'received message ID different than expected (%s)'}, # TODO: critical error, should have level 0
	  3012 => {level=>6,msg=>'received message ID is as expected'},
	# NxServer::Clients  (+-)  4000 ..  4999
	  4000 => {level=>4,msg=>'created'},
	 -4001 => {level=>0,msg=>'no way how to wait for clients'},
	  4002 => {level=>4,msg=>'client process forked (PID:%i)'},
	 -4003 => {level=>0,msg=>'client process did not forked'},
	 -4004 => {level=>0,msg=>'IPC error'},
	  4005 => {level=>4,msg=>'IPC initialized'},
	  4006 => {level=>4,msg=>'client process exited (PID:%i)'},
	 -4007 => {level=>0,msg=>'internal error: trying to decrease undefined number of connected clients'},
	 -4008 => {level=>0,msg=>'IPC error - unknown command'},
	# NxServer::Clients::TCP  (+-)  5000 ..  5999
	  5000 => {level=>4,msg=>'created'},
	  5002 => {level=>4,msg=>'connection opened from %s'},
	 -5001 => {level=>0,msg=>'could not bind %s'},
	 -5003 => {level=>4,msg=>'refused connection from %s'},
	# NxServer::Clients::TCP-SSL  (+-)  6000 ..  6999
	  6000 => {level=>4,msg=>'created'},
	  6002 => {level=>4,msg=>'connection opened from %s'},
	 -6001 => {level=>0,msg=>'could not bind %s'},
	 -6003 => {level=>4,msg=>'refused connection from %s'},
	# NxServer::Storage::Memory   (+-)  7000 ..  7999
	  7000 => {level=>4,msg=>'created'},
	# NxClient         			  (+-) 20000 .. 20999 
	 20000 => {level=>1,msg=>'created'},
	-20001 => {level=>0,msg=>'unknown client type'},
	-20002 => {level=>0,msg=>'unknown server address (host, port)'},
	-20003 => {level=>0,msg=>'unknown client type'},
	-20004 => {level=>0,msg=>'authentication settings not received from server'},
	 20005 => {level=>4,msg=>'received server\'s invitation message'},
	-20006 => {level=>0,msg=>'unknown AUTH request (%s)'},
	 20007 => {level=>4,msg=>'connected without authentication'},
	 20008 => {level=>4,msg=>'authentication required, sent password'},
	-20009 => {level=>0,msg=>'authentication required but I don\'t know password'},
	 20010 => {level=>4,msg=>'authentication passed'},
	-20011 => {level=>0,msg=>'authentication failed'},
	-20012 => {level=>0,msg=>'unknown authentication status'},
	-20013 => {level=>0,msg=>'did not received OK READY'},
	 20014 => {level=>4,msg=>'server is ready for commands'},
	-20015 => {level=>0,msg=>'unknown inputchannel status (%s)'},
	 20016 => {level=>4,msg=>'sent inputchannel command (%s)'},
	-20017 => {level=>3,msg=>'failed to send inputchannel command (%s)'},
	 20018 => {level=>4,msg=>'sent getchannel push command (%s)'},
	-20019 => {level=>3,msg=>'failed to send getchannel push command (%s)'},
	 20020 => {level=>4,msg=>'sent getchannel level command (%s)'},
	-20021 => {level=>3,msg=>'failed to send getchannel level command (%s)'},
	 20022 => {level=>4,msg=>'sent getchannel text command (%s)'},
	-20023 => {level=>3,msg=>'failed to send getchannel text command (%s)'},
	-20024 => {level=>0,msg=>'communication with NxServer timed-out'},
	-20025 => {level=>0,msg=>'connection failed (%s)'},
	# NxClient::TCP    			  (+-) 21000 .. 21999 
	 21000 => {level=>4,msg=>'created'},
	-21001 => {level=>0,msg=>'unknown host'},
	-21002 => {level=>0,msg=>'unknown port'},
	-21003 => {level=>0,msg=>'NxServer connect failed'},
	 21004 => {level=>4,msg=>'connected to NxServer (%s)'},
	# NxClient::SSL    			  (+-) 22000 .. 22999 
	 22000 => {level=>4,msg=>'created'},
	-22001 => {level=>0,msg=>'unknown host'},
	-22002 => {level=>0,msg=>'unknown port'},
	-22003 => {level=>0,msg=>'NxServer connect failed'},
	 22004 => {level=>4,msg=>'connected to NxServer (%s)'},
	# NxWeb		    			  (+-) 30000 .. 30999 
	 30001 => {level=>1,msg=>'created'},
	 30002 => {level=>4,msg=>'config file checked'},
	-30003 => {level=>0,msg=>'incomplete configuration (%s)'},
	-30004 => {level=>0,msg=>'cannot read configuration'},
	-30005 => {level=>0,msg=>'failed to create HTML::Template'},
	-30006 => {level=>0,msg=>'trying to show undefined template'},
	-30007 => {level=>3,msg=>'coudn\'t log access to application'},
	-30008 => {level=>0,msg=>'none script language specified'},
	-30009 => {level=>0,msg=>'no appname specified'},
	# NxWeb::Db					  (+-) 31000 .. 31999
	 31000 => {level=>1,msg=>'created'},
	 31002 => {level=>4,msg=>'connected to db'},
	-31001 => {level=>0,msg=>'failed to connect to db'},
	-31003 => {level=>0,msg=>'db is not responding to ping'},
	# NxWeb::Lang				  (+-) 32000 .. 32999
	 32000 => {level=>1,msg=>'created'},
	-32001 => {level=>0,msg=>'there are no language codes'},
	# NxWeb::CGI           		  (+-) 33000 .. 33999
	 33000 => {level=>1,msg=>'created'},
	 33001 => {level=>4,msg=>'script param: %s'},
	 33002 => {level=>4,msg=>'strict param: %s'},
	-33003 => {level=>4,msg=>'unstrict param: %s'},
	 33005 => {level=>4,msg=>'strict URL param: %s'},
	-33006 => {level=>4,msg=>'unstrict URL param: %s'},
	-33007 => {level=>0,msg=>'accessed undefined Query'},
	# NxWeb::Clients    		  (+-) 34000 .. 34999
	 34000 => {level=>1,msg=>'created'},
	-34001 => {level=>0,msg=>'error getting action_id %i'},
	-34002 => {level=>3,msg=>'coudn\'t log access to action %i'},
	-34003 => {level=>3,msg=>'unknown action_id %i'},
	-34004 => {level=>3,msg=>'cannot convert user %s to login and log access to action'},
	-34005 => {level=>3,msg=>'couln\'t convert action %i to address'},
	-34006 => {level=>3,msg=>'unknown action_id %i'},
	-34007 => {level=>3,msg=>'unknown action_id %i'},
	-34008 => {level=>3,msg=>'unknown action_id %i'},
	-34009 => {level=>0,msg=>'error getting status_id %i'},
	-34010 => {level=>3,msg=>'couln\'t convert status %i to address'},
	# NxWeb::People        		  (+-) 35000 .. 35999
	 35000 => {level=>1,msg=>'created'},
	# NxWeb::Rights               (+-) 36000 .. 36999
	 36000 => {level=>1,msg=>'created'}
);


=item %codes_belongs

Hash with information about which message range belongs to which Perl module.
Keys are numbers and values are names of Perl modules. Range is specified as
from (-1000)*key number to (1000)*key number.

=cut
my %codes_belongs=(
	0	=> 'NxServer',
	1	=> 'NxServer::Poll',
	2	=> 'NxServer::Storage',
	3	=> 'NxServer::Protocol',
	4	=> 'NxServer::Clients',
	5	=> 'NxServer::Clients::TCP',
	6	=> 'NxServer::Clients::SSL',
	20	=> 'NxClient',
	21	=> 'NxClient::TCP',
	22	=> 'NxClient::SSL',
	30	=> 'NxWeb',
	31	=> 'NxWeb::Db',
	32	=> 'NxWeb::Lang',
	33	=> 'NxWeb::CGI',
	34	=> 'NxWeb::Clients',
	35	=> 'NxWeb::People',
	36	=> 'NxWeb::Rights'
);


=item %config_nxserver_content

Hash with all mandatory content of NxServer configuration.

=cut
my %config_nxserver_content=(
	'netlinx'			=> ['name','port'],
	'id'				=> ['name','count','device_low','device_high'],
	'log'				=> ['level','file'],
	'clients-tcp'		=> ['name','port','allow_from','welcome_msg','password','max_clients'],
	'clients-tcpssl'	=> ['name','port','allow_from','welcome_msg','ssl_key','cert_file','password','max_clients'],
	'nxserver'			=> ['poll_sleep_low','poll_sleep_high','poll_sleep_idle','get_message_delay','pulse_on_connect']
);


=item %config_nxweb_content

Hash with all possible content of NxServer configuration. Every hash element
contains reference to hash with possible keys:

=over 8

=item mandatory

with value 1 (if this section must be in configuration) or 0 (if this
can be in configuration).

=item vars

is reference to array with all required values of section

=back

=cut
my %config_nxweb_content=(
	'app-defaults'      => {vars=>['lang']},
	'db'                => {vars=>['host','port','user','database','password']},
	'template'          => {vars=>['templates','layouts']},
	'client1'           => {vars=>['type','host','port','password']},
	'client2'           => {mandatory=>0,vars=>['type','host','port','password']},
	'client3'           => {mandatory=>0,vars=>['type','host','port','password']},
	'client4'           => {mandatory=>0,vars=>['type','host','port','password']},
	'client5'           => {mandatory=>0,vars=>['type','host','port','password']}
);


=item Globals->get_config_content($config_number);

Returns HASH reference to required content of configuration file.

=cut
sub get_config_content($) {
	my $config_number=shift || 1;

	if ($config_number==1) {
		return(\%config_nxserver_content);
	} elsif ($config_number==2) {
		return(\%config_nxweb_content);
	} else {
		die('Unknown configuration');
	}
}


=item Globals->status_ok($code)

Returns 1 if $code is possitive, 0 if negative.

=cut
sub status_ok($) {
	my $status=shift;
	return(! defined $status || $status>0?1:0);
}


=item Globals->status_codes($code)

Returns HASH with info about code. Hash containts keys
'level' with log level and 'msg' with text message.

=cut
sub status_codes($) {
	my $code=shift;
	return($codes{$code});
}


=item Globals->status_codes_belongs

Returns name of module to which code belongs.

=cut
sub status_codes_belongs($) {
	my $code=shift;
	my $code_base=int(abs($code)/1000);

	# return module name if known
	if (exists $codes_belongs{$code_base}) {
		return($codes_belongs{$code_base});
	} else {
		return('unknown');
	}
}


1;
