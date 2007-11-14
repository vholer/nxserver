#!/usr/bin/perl -w
#
# Check for presence of all required modules
#

# required by scripts
use IO::Socket;
use IO::Socket::SSL;
use IO::Socket::INET;
use DBI;
use DBD::Pg;
use XML::Mini::Document;
use Time::HiRes qw(usleep);
use CGI;
use I18N::AcceptLanguage;
use HTML::Template;
use Config::Tiny;

# standard modules
use strict;
use Exporter;
use POSIX;
use Carp;
use Socket qw(:DEFAULT :crlf);
