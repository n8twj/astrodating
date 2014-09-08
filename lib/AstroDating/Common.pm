package AstroDating::Common;

use strict;
use warnings;
use base 'Exporter';
use Log::Handler;
use Config::Any;
use Data::Dumper;
use Sys::Hostname;

our @EXPORT = qw($AMI $AMI_VER $config $log $engine $active_data);

our $AMI;
our $AMI_VER;
our $config;
our $log;
our $engine;
our $active_data = {};

sub reload_config {
	if ($config) {
		$config = undef;
	}
	$config =  Config::Any->load_files( { files => ['etc/astrodating.ini'], use_ext => 1 } )->[0]->{'etc/astrodating.ini'}->{'AstroDating'} 
		or die("[" . scalar (localtime) . "]: Unable to open configuration file");
	$log = Log::Handler->new();
	
	$log->add( 
		file => { 
			filename => $config->{'logfile'} || 'logs/astrodating-engine.log',
			maxlevel => 'debug',
			minlevel => 'warning'
		}
	);
	$log->info("Configuration Loaded");
}

reload_config();

1;
