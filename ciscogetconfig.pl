#!/usr/bin/perl 
#===============================================================================
#
#         FILE: ciscogetconfig.pl
#
#        USAGE: ./ciscogetconfig.pl  
#
#  DESCRIPTION: 
#
#      OPTIONS: ---
# REQUIREMENTS: ---
#         BUGS: ---
#        NOTES: ---
#       AUTHOR: Frank Cui (), frankcui24@gmail.com
#      COMPANY: Internetworking Lab
#      VERSION: 0.9
#      CREATED: 12-01-11 10:07:38 AM
#     REVISION: ---
#===============================================================================

use strict;
use warnings;
use Net::Telnet::Cisco;
use Log::Message::Simple qw[msg error debug];
use File::Spec::Functions;

my $verbose = 1;
my @routerlist;

my $conffile = "/home/ycui/sample.cfg";
open (my $CONF,'<',$conffile) or die "cannot open the config file";

my %samplerouter = (
	'routername' => '',
	'directory' => '',
	'host' => '',
	'username' => '',
	'password' => '',
	'enable' => '',
);


my %router = ();
my $linenum = 0;
while ($_ = <$CONF>)
{
    $linenum++;
	# some processing of config file
	next if /^#/;
	next if /^\s*$/;
	s/\s*#.*$//;
	chomp;

	if (/^END$/)
	{
		push @routerlist,\%router;
	}
	elsif (/^\[\s*(\w+)\s+dir=\s*([\w\/]+)\s*\]\s*$/)
	{
		foreach my $param (keys %samplerouter)
		{
			if (exists $router{$param})
			{
				my $routerref = \%router;
				my $copied_router = {%{$routerref}};
				push @routerlist,$copied_router;
				last;	
			}
		}
		$router{'routername'} = $1;
		$router{'directory'}  = $2;
	}
	elsif (/^\s*([\w.]+)\s*=\s*([\w.]+)\s*$/)
	{
		my $key         = $1;
		my $value       = $2;
		die "|$router{'routername'}| invalid key value : $key " unless (grep {$_ eq $key} keys %samplerouter);
		$router{ $key } = $value;
	}
	else
	{
		die "Config file isn't made approprately at line $linenum";
	}
}

# Check if we have got all the required parameters
foreach my $routerref (@routerlist)
{
	foreach my $param (keys %samplerouter) {
		next if ($param eq 'username');
		die "|$routerref->{'routername'}| $param : required but not found in config file" unless (grep {$_ eq $param} keys %{$routerref});
	}
}

sub fetchconfig($)
{
	my $routerref = shift;
	eval 
	{ 
		msg("|$routerref->{'routername'}| : Starting the connection..." , $verbose) ;
		my $session = Net::Telnet::Cisco->new(Host => $routerref->{'host'}); 
                msg("|$routerref->{'routername'}| : Telnet Connection Established" , $verbose) ;
		if (defined $routerref->{'username'})
		{
			$session->login($routerref->{'username'}, $routerref->{'password'});
		}
		else
		{
			$session->login($routerref->{'password'});
		}
                msg("|$routerref->{'routername'}| : Telnet Authentication Passed" , $verbose) ;
		$session->enable($routerref->{'enable'});
		msg("|$routerref->{'routername'}| : Getting into priviledged mode" , $verbose) ;
                my @config = $session->cmd('show run');
                msg("|$routerref->{'routername'}| : Fetching the config to local machine, now saving it...", $verbose) ;
		unless ( -d $routerref->{'directory'})
		{
            		msg("|$routerref->{'routername'}| : Specified directory $routerref->{'directory'} doesn't exist,trying to create it",$verbose) ;
			mkdir $routerref->{'directory'};
		}
		msg ("|$routerref->{'routername'}| : Change into directory : $routerref->{'directory'}",$verbose);
		chdir $routerref->{'directory'};
		if ( -f $routerref->{'routername'})
		{
			msg("|$routerref->{'routername'}| : specified routername for already exists, not overriding)", $verbose);
		}
		else
		{
			open (my $fh,">",$routerref->{'routername'} . ".cfg");
			print $fh @config;
			my $path = &catfile ($routerref->{'directory'},$routerref->{'routername'} . ".cfg");
			msg("|$routerref->{'routername'}| : successfully fetch and save the configuration file to $path", $verbose);
		}
	};
	error("error occured in fetching or saving config for |$routerref->{'routername'}| : $@" , $verbose) if ($@);
}

for my $routerref (@routerlist)
{
    msg("Trying to fecthing Configuration from |$routerref->{'routername'}|", $verbose);
    &fetchconfig($routerref);
}
