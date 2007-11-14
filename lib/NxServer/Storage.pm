=head1 NAME

NxServer::Storage - Abstract storage class for data

=head1 DESCRIPTION

=over

=cut

package NxServer::Storage;

use strict;
use Exporter;
use DBI;
use NxServer::Storage::Memory;


=item NxServer::Storage->new($nxserver);

Initializes object, expects reference to NxServer.
Creates memory storage class.

=cut
sub new($$) {
	my $self={};
	bless($self,shift);
	$self->{'_nxserver'}=shift;

	# storage types
	$self->{'_storage_types' }=();
	$self->{'_storage_memory'}=NxServer::Storage::Memory->new($self->nxserver());
	push(@{$self->{'_storage_types'}},$self->{'_storage_memory'}); 

	# there are no Client subobjects
	$self->print_debug(-2001)
		if scalar(@{$self->{'_storage_types'}})==0;

	# Storage created
	$self->print_debug(2000);
	return($self);
}



=item NxServer::Storage->init_structures;

Initializes internal structures of all available storage types (Memory,...).

=cut
sub init_structures($) {
	my $self=shift;
	for my $clientt (@{$self->{'_storage_types'}}) {
		$clientt->init_structures();
	}
}



=item NxServer::Storage->set_push_channel($device_order,$channel,$status);

Stores channel $status provided for $device_order and $channel. Status
should be value 0 or 1.

=cut
sub set_push_channel($$$$) {
	my $self=shift;
	$self->print_debug(2002);
	for my $clientt (@{$self->{'_storage_types'}}) {
		$clientt->set_push_channel(@_);
	}
}


=item NxServer::Storage->get_push_channel($device_order,$channel);

Get value of Push Channel ($channel) from device in $device_order.

=cut
sub get_push_channel($$$) {
	my $self=shift;
	$self->print_debug(2003);
	return($self->{'_storage_memory'}->get_push_channel(@_));
}


=item NxServer::Storage->set_level_channel($device_order,$channel,$value,$value_type);

Stores $value and $value_type provided for $device_order and $channel.

=cut
sub set_level_channel($$$$$) {
	my $self=shift;
	$self->print_debug(2004);
	for my $clientt (@{$self->{'_storage_types'}}) {
		$clientt->set_level_channel(@_);
	}
}


=item NxServer::Storage->get_level_channel($device_order,$channel);

Get value of Level Channel ($channel) from device in $device_order.

=cut
sub get_level_channel($$$) {
	my $self=shift;
	$self->print_debug(2005);
	return($self->{'_storage_memory'}->get_level_channel(@_));
}


=item NxServer::Storage->set_variabletext_channel($device_order,$channel,$value,$value_type);

Stores $value and $value_type provided for $device_order and $channel.
This method is for storing data received in CommandSend messages.

=cut
sub set_variabletext_channel($$$$$) {
	my $self=shift;
	$self->print_debug(2006);
	for my $clientt (@{$self->{'_storage_types'}}) {
		$clientt->set_variabletext_channel(@_);
	}
}


=item NxServer::Storage->get_variabletext_channel($device_order,$channel);

Get value from CommandSend message for $device_order and $channel.

=cut
sub get_variabletext_channel($$$) {
	my $self=shift;
	$self->print_debug(2007);
	return($self->{'_storage_memory'}->get_variabletext_channel(@_));
}


=item NxServer::Storage->level_data2str($hash_level_data);

Returns formated Level data from $hash_level_data hash reference. With keys
'value_type' and 'value'. Method returns formated string $value_type:$value.

=cut
sub level_data2str($$) {
	my ($self,
		$data
	) = @_;

	return(sprintf("%s:%s",$data->{'value_type'},$data->{'value'}));
}


=item NxServer::Storage->push_data2str($hash_push_data);

Returns formated Push data from $hash_push_data hash reference. With key
'status'. Method returns formated string $status.

=cut
sub push_data2str($$) {
	my ($self,
		$data
	) = @_;

	return(sprintf("%s",$data->{'status'}));
}

=item NxServer::Storage->text_data2str($hash_text_data);

Returns formated Variable text data from $hash_text_data hash reference. With keys
'value_type' and 'value'. Method returns formated string $value_type:$value.

=cut
sub text_data2str($$) {
	my ($self,
		$data
	) = @_;

	return(sprintf("%s:%s",$data->{'value_type'},$data->{'value'}));
}


=item NxServer::Storage->nxserver();

Returns pointer to object NxServer.

=cut
sub nxserver($) {
	my $self=shift;
	return($self->{'_nxserver'});
}


=item NxServer::Storage->print_debug($code,[$additional_text]);

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
