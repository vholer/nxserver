=head1 NAME

NxClient - Connection class to NxServer

=head1 DESCRIPTION

=over

=cut

package NxClient;

use strict;
use Exporter;
use NxGlobals;
use NxClient::TCP;
use NxClient::SSL;
use Carp qw(confess);


=item NxClient->new([params]);

Creates new object. Parameters are mandatory and inserted
like hash with theses keys:

=over 16

=item host

hostname or IP of NxServer

=item port

port of NxServer service

=item type

type of connection, possible values are TCP for unecrypted connection and SSL
for encrypted

=item password

password for authenticated connection to NxServer

=item timeout

timeout with communication with NxServer (default is 10s)

=back

Example:

  my $nxcilent=NxClient->new(
  	type=>'ssl',
  	host=>'localhost',
  	port=>1234,
  	password=>'foo'
  );

=cut
sub new {
	my $self={};
	bless($self,shift);

	# parameters processing
	my %params=@_;
	$self->{'_debug'}=$params{'debug'} || 0;	#debug
	$self->{'_type'}=$params{'type'}  || $self->print_debug(-20001);
	$self->{'_host'}=$params{'host'};
	$self->{'_port'}=$params{'port'};
	$self->{'_password'}=$params{'password'};
	$self->{'_timeout'}=$params{'timeout'} || 10;

	# TCP
	if (uc($self->{'_type'}) eq 'TCP') {
		# do I have all needed parameters? 
		$self->print_debug(-20002)
			unless defined $params{'host'} && defined $params{'port'};
		# connect
		$self->{'_conn_o'}=NxClient::TCP->new(
			$self, $params{'host'},$params{'port'}
		);

	# TCP/SSL
	} elsif (uc($self->{'_type'}) eq 'SSL') {
		# do I have all needed parameters? 
		$self->print_debug(-20002)
			unless defined $params{'host'} && defined $params{'port'};
		# connect
		$self->{'_conn_o'}=NxClient::SSL->new(
			$self, $params{'host'},$params{'port'}
		);

	# unknown
	} else {
		$self->print_debug(-20003);
	}

	# do conversation
	$self->do_init_conversation;

	# NxClient created
	$self->print_debug(20000);
	return($self);
}


=item NxClient->do_init_conversation;

Do initial conversation with NxServer, e.g. authentication. Expects
connection opened to NxServer.

=cut
sub do_init_conversation($) {
	my $self=shift;

	my $handle=$self->conn_socket;

	# at first server send invitation (or not)
	my $msg=<$handle>;
	if ($msg=~/^\+OK TEXT/) {
		$self->print_debug(20005);
		$msg=<$handle>;
	}

	# max. clients exceeded (??)
	$self->print_debug(-20025,$1)
		if $msg=~/^-ERR TEXT:\s*(.*)/;

	# authentication
	if (my ($status)=$msg=~/^\+OK AUTH:(.*)/) {
		# no authentication
		if ($status=~/^NO/i) {
			$self->print_debug(20007);

		# authentication
		} elsif ($status=~/^YES/i) {
			unless (defined $self->{'_password'}) {
				# we don't know password
				$self->print_debug(-20009);
			} else {
				# send password
				print($handle $self->{'_password'},"\n");
				$self->print_debug(20008,$status);

				# and read response
				$msg=<$handle>;
				if ($msg=~/^\+OK AUTH/i) {
					$self->print_debug(20010);
				} elsif ($msg=~/^-ERR AUTH/i) {
					$self->print_debug(-20011);
				} else {
					$self->print_debug(-20012);
				}
			}
		} else {
			$self->print_debug(-20006,$status);
		}
	} else {
		$self->print_debug(-20004);
	}

	# get READY
	$msg=<$handle>;

	if ($msg=~/^\+OK READY/i) {
		$self->print_debug(20014);
	} else {
		$self->print_debug(-20013);
	}
}


=item NxClient->send_inputchannel($device,$channel,$status);

Send to $device and $channel input channel to $status.
Status is one of theses texts: on, off, pulse

=cut
sub send_inputchannel($$$$) {
	my ($self,
		$device,
		$channel,
		$status
	) = @_;

	$self->print_debug(-20015)
		unless $status=~/^(on|off|pulse)$/i;

	# send ...
	my $msg_out='setchannel %s %i %i'."\n";
	$self->server_print(sprintf($msg_out,$status,$device,$channel));
	
	# ... expect OK
	my $debug_info=sprintf("%s %i:%i",$status,$device,$channel);
	my $msg_in=$self->server_read;
	if ($msg_in=~/^\+OK/) {
		$self->print_debug(20016,$debug_info);
	} else {
		$self->print_debug(-20017,$debug_info);
	}
}


=item NxClient->send_getchannel_push($device,$channel);

Sends command to NxServer:

  getchannel push $device $channel

Response from server is returned as function result.

=cut
sub send_getchannel_push($$$) {
	my ($self,
		$device,
		$channel
	) = @_;

	# send ...
	my $msg_out='getchannel push %i %i'."\n";
	$self->server_print(sprintf($msg_out,$device,$channel));
	
	# ... expect OK
	my $debug_info=sprintf("%i:%i",$device,$channel);
	my $msg_in=$self->server_read;
	if ($msg_in=~/^\+OK DATA:(.*)/) {
		$self->print_debug(20018,$debug_info.'-'.$1);
		return($1);
	} else {
		$self->print_debug(-20019,$debug_info);
	}
}


=item NxClient->send_getchannel_level($device,$channel);

Sends command to NxServer:

  getchannel level $device $channel

Response from server is returned as function result.

=cut
sub send_getchannel_level($$$) {
	my ($self,
		$device,
		$channel
	) = @_;

	# send ...
	my $msg_out='getchannel level %i %i'."\n";
	$self->server_print(sprintf($msg_out,$device,$channel));
	
	# ... expect OK
	my $debug_info=sprintf("%i:%i",$device,$channel);
	my $msg_in=$self->server_read;
	if ($msg_in=~/^\+OK DATA:(.*)/) {
		$self->print_debug(20020,$debug_info.'-'.$1);
		my ($type,$value)=split(/:/,$1);
		return($value);
	} else {
		$self->print_debug(-20021,$debug_info);
	}
}


=item NxClient->send_getchannel_text($device,$channel);

Sends command to NxServer:

  getchannel text $device $channel

Response from server is returned as function result.

=cut
sub send_getchannel_text($$$) {
	my ($self,
		$device,
		$channel
	) = @_;

	# send ...
	my $msg_out='getchannel text %i %i'."\n";
	$self->server_print(sprintf($msg_out,$device,$channel));
	
	# ... expect OK
	my $debug_info=sprintf("%i:%i",$device,$channel);
	my $msg_in=$self->server_read;
	if ($msg_in=~/^\+OK DATA:(.*)/) {
		$self->print_debug(20022,$debug_info.'-'.$1);
		my ($type,$value)=split(/:/,$1);
		return($value);
	} else {
		$self->print_debug(-20023,$debug_info);
	}
}


=item NxClient->server_print($text);

Sends $text to NxServer.

=cut
sub server_print($$) {
	my ($self,
		$text
	) = @_;
	
	my $handle=$self->conn_socket;
	print($handle $text);
}


=item NxClient->server_read;

This function returns one line read from NxServer.

=cut
sub server_read($) {
	my $self=shift;

	# alarmed read
	my $line;
	eval {
		local $SIG{ALRM}=sub{die 'alarm'};
		alarm($self->{'_timeout'});
		my $handle=$self->conn_socket;
		$line=<$handle>;
		alarm(0);
	};

	if ($@ and $@ eq 'alarm') {
		$self->print_debug(-20024);
	} else {
		return($line);
	}
}


=item NxClient->close;

Closes connection to NxServer - sends QUIT and closes connection.

=cut
sub close($) {
	my $self=shift;

	# send quit command
	my $handle=$self->conn_socket;
	print($handle "QUIT\n");

	# close sockets
	$self->conn_o->close;
}


=item NxClient->print_debug($code[,$additional_text]);

According to code number writes message to STDERR. List of
all codes is in NxClient::Globals module.

=cut
sub print_debug {
	my ($self,
		$code,
		$text
	) = @_;
	
	my $code_info=status_codes($code);

	# additional info?
	if (defined $code_info) {
		# print debug if user want
		if ($code_info->{'level'}<=$self->{'_debug'}) {
			my $module_name=status_codes_belongs($code);
			my $error_text=sprintf($code_info->{'msg'},(defined $text?$text:'?'));
			printf(STDERR "%5i:%-20s-%s\n",$code,$module_name,$error_text);
		}

		# die if this is critical error
		confess($code) if $code_info->{'level'}==0 && $code<0;

		return($code);
	} else {
		confess(sprintf("There are no additional information at error code %i",$code));
	}
}


=item NxClient->conn_o();

Returns pointer to client connection class (NxClient::TCP or NxClient::SSL).

=cut
sub conn($) {
	my $self=shift;
	return($self->{'_conn_o'});
}


=item NxClient->conn_socket();

Returns connection handle to NxServer.

=cut
sub conn_socket() {
	my $self=shift;
	return($self->{'_conn_o'}->conn_socket);
}

# TODO: DESTROY pro uzavreni socketu

1;


=head1 AUTHOR

Vlastimil Holer (xholer@fi.muni.cz)

=cut
