#!/usr/bin/perl -w
# GNU/GPL, Vlastimil Holer <holer@fi.muni.cz>
# Faculty of Informatics, Masaryk University Brno, Czech Republic
use strict;
use lib "../lib/"; 
use NxClient;

my $nxclient=NxClient->new(
	debug=>7,
	type=>'tcp',
	host=>'localhost',
	port=>'1234',
	password=>'xyz'
);

##### Some commands now, e.g.:
#
# $nxclient->send_inputchannel(1,7,'pulse');
# sleep 1;
# $nxclient->send_inputchannel(1,37,'pulse');
# print $nxclient->send_getchannel_text(1,5),"\n";

1;
