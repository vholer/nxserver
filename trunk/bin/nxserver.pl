#!/usr/bin/perl -w
# GNU/GPL, Vlastimil Holer <holer@fi.muni.cz>
# Faculty of Informatics, Masaryk University Brno, Czech Republic
use strict;
use lib "../lib/"; 
use NxServer;
use Getopt::Std;

# take parameters
my %opts;
getopts('c:d:',\%opts);

if (exists $opts{'c'}) {
	my $nxcenter=NxServer->new($opts{'c'},$opts{'d'});
	local $SIG{INT}=$SIG{TERM}=$SIG{KILL}=sub {
		$nxcenter->close;
		die('Finished')
	};
	$nxcenter->go_loop();
} else {
	# not enough parameters
	print(STDERR <<EOF);
NxServer, Netlinx communication proxy
Copyright 2003-2004, Vlastimil Holer <xholer\@fi.muni.cz>, GNU/GPL
	
List of options:
-c file     configuration
-d num      debug logging
EOF
};

1;
