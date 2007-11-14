=head1 NAME

NxServer - Main NxServer class

=head1 DESCRIPTION

=over 4

=cut

package NxServer;

use strict;
use Exporter;
use Carp qw(confess);
use NxGlobals;
use NxServer::Poll;
use NxServer::Storage;
use NxServer::Clients;
use Config::Tiny;
use Time::HiRes qw( usleep );



=item NxServer->new([$config_file[,$debug_level]]);

Initializes new object. Creates new NxServer with configuration read from $config_file
(default is '/opt/nxutils/etc/nxserver.ini') and $debug_level (default to 0).

=cut
sub new {
	my $self={};
	bless($self,shift);
	$self->{'_config_file'}=shift || '/opt/nxutils/etc/nxserver.ini';
	$self->{'_debug'}=shift || 0;

	# create configuration
	$self->{'_nxconfig'}=Config::Tiny->read($self->{'_config_file'});
	$self->print_debug(-2) unless defined $self->{'_nxconfig'};

	my $rtn=$self->check_config;
	$self->print_debug(($rtn?-3:2),$rtn);

	# create storage object for data
	$self->{'_nxstorage'}=NxServer::Storage->new($self);

	# create polling process; if unsuccessfull => DIE
	$self->{'_nxpoll'}=NxServer::Poll->new($self) ||
		$self->print_debug(-1005);

	# create client service
	$self->{'_nxclients'}=NxServer::Clients->new($self);

	# NxServer created
	$self->print_debug(1);
	return($self);
}


=item NxServer->close;

Closes all connections and destroys all objects. Then we are
ready to destroy NxServer object and quit program.

=cut
sub close($) {
	my $self=shift;
	$self->nxpoll->done_nx;
}


=item NxServer->check_config;

Checks wheater configuration file containts all needed properties.
Returns section.parameter if missing, otherwise nothing.

=cut 
sub check_config($) {
	my $self=shift;
	my $config_content=get_config_content(1);
	for my $section (keys %$config_content) {
		for my $property (@{$$config_content{$section}}) {
			return "$section.$property"
				unless defined $self->nxconfig()->{$section}->{$property};
		}
	}

	# check syntax of nxserver->pulse_on_connect item
	$self->{'_pulse_on_connect'}=[];
	for my $address (split(/;/,$self->nxconfig->{'nxserver'}->{'pulse_on_connect'})) {
		my ($device,$channel)=split(/,/,$address);
		if ($device=~/^\d+$/ && $channel=~/^\d+$/) {
			push(@{$self->{'_pulse_on_connect'}},{
				device	=> $device,
				channel	=> $channel
			});
		} else {
			$self->print_debug(-4,$address);
		}
	}

	return;
}

=item NxServer->print_debug($code[,$additional_text]);

According to code number writes message to STDERR. List of
all codes is in NxServer::Globals module.

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
		die if $code_info->{'level'}==0 && $code<0;

		return($code);
	} else {
		confess(sprintf("There are no additional information at error code %i",$code));
	}
}



=item NxServer->go_loop();

This is never-ending loop with calling NxServer->poll() function.

=cut
sub go_loop($) {
	my $self=shift;

	while(1) {
		$self->poll();

    	# wait -- because Netlinx is slower than we are :)
    	# this can be modified depending on NxServer machine strength;
    	# for P4 2.6GHz is default setting just right

		# if there was no communicaation in last $poll_sleep_idle poll loops,
		# then there will be longer delays between polls.
		my $poll_sleep_idle=$self->nxconfig->{'nxserver'}->{'poll_sleep_idle'};
		if ($self->nxpoll->go_idle>$poll_sleep_idle) {
    		usleep($self->nxconfig()->{'nxserver'}->{'poll_sleep_high'});
		} else {
    		usleep($self->nxconfig()->{'nxserver'}->{'poll_sleep_low'});
		}
	}
}



=item NxServer->poll();

This calls poll() function of importatant objects (NxServer::Poll,
NxServer::Clients etc.).

=cut
sub poll($) {
	my $self=shift;

	$self->nxclients->poll;
	$self->nxpoll->poll;
}


=item NxServer->nxpoll();

Returns pointer to object NxServer::Poll.

=cut
sub nxpoll($) {
	my $self=shift;
	return($self->{'_nxpoll'});
}


=item NxServer->nxstorage();

Returns pointer to object NxServer::Storage.

=cut
sub nxstorage($) {
	my $self=shift;
	return($self->{'_nxstorage'});
}


=item NxServer->nxconfig();

Returns pointer to structure with configuration.

=cut
sub nxconfig($) {
	my $self=shift;
	return($self->{'_nxconfig'});
}


=item NxServer->nxclients();

Returns pointer to object NxServer::Clients.

=cut
sub nxclients($) {
	my $self=shift;
	return($self->{'_nxclients'});
}


1;


=head1 AUTHOR

Vlastimil Holer (holer@fi.muni.cz)

=cut
