=head1 NAME

NxServer::Storage::Memory - Memory storage class for data

=head1 DESCRIPTION

=over

=cut

package NxServer::Storage::Memory;

use strict;
use Exporter;
use DBI;


=item NxServer::Storage::Memory->new($nxserver);

Initializes new object, expects pointer to NxServer.

=cut
sub new($$) {
	my $self={};
	bless($self,shift);
	$self->{'_nxserver'}=shift;

	# Storage created
	$self->print_debug(7000);
	return($self);
}


=item NxServer::Storage::Memory->init_structures;

Clears all stored data.

=cut
sub init_structures($) {
	my $self=shift;

	# internal structures
	$self->{'_db_channels'}={};
	$self->{'_db_levels'}={};
	$self->{'_db_texts'}={};
}


=item NxServer::Storage::Memory->set_push_channel($device_order,$channel,$status);

See wrapper NxServer::Storage;

=cut
sub set_push_channel($$$$) {
	my ($self,
		$device_order,
		$channel,
		$status
	) = @_;

	# set
	$self->{'_db_channels'}->{$device_order}->{$channel}={
		status=>$status,
		changed=>time()
	};
}


=item NxServer::Storage::Memory->get_push_channel($device_order,$channel);

See wrapper NxServer::Storage;

=cut
sub get_push_channel($$$) {
	my ($self,
		$device_order,
		$channel
	) = @_;

	# get
	return($self->{'_db_channels'}->{$device_order}->{$channel})
		if exists $self->{'_db_channels'}->{$device_order}->{$channel};
}


=item NxServer::Storage::Memory->set_level_channel($device_order,$channel,$value,$value_type);

See wrapper NxServer::Storage;

=cut
sub set_level_channel($$$$$) {
	my ($self,
		$device_order,
		$channel,
		$value,
		$value_type
	) = @_;

	# set
	$self->{'_db_levels'}->{$device_order}->{$channel}={
		value=>$value,
		value_type=>$value_type,
		changed=>time()
	};
}


=item NxServer::Storage::Memory->get_level_channel($device_order,$channel);

See wrapper NxServer::Storage;

=cut
sub get_level_channel($$$) {
	my ($self,
		$device_order,
		$channel
	) = @_;

	# get
	return($self->{'_db_levels'}->{$device_order}->{$channel})
		if exists $self->{'_db_levels'}->{$device_order}->{$channel};
}


=item NxServer::Storage::Memory->set_variabletext_channel($device_order,$channel,$value,$value_type);

See wrapper NxServer::Storage;

=cut
sub set_variabletext_channel($$$$$) {
	my ($self,
		$device_order,
		$channel,
		$value,
		$value_type
	) = @_;

	# set
	$self->{'_db_texts'}->{$device_order}->{$channel}={
		value=>$value,
		value_type=>$value_type,
		changed=>time()
	};
}


=item NxServer::Storage::Memory->get_variabletext_channel($device_order,$channel);

See wrapper NxServer::Storage;

=cut
sub get_variabletext_channel($$$) {
	my ($self,
		$device_order,
		$channel
	) = @_;

	# get
	return($self->{'_db_texts'}->{$device_order}->{$channel})
		if exists $self->{'_db_texts'}->{$device_order}->{$channel};
}


=item NxServer::Storage::Memory->nxserver();

Returns pointer to object NxServer.

=cut
sub nxserver($) {
	my $self=shift;
	return($self->{'_nxserver'});
}


=item NxServer::Storage::Memory->print_debug($code,[$additional_text]);

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
