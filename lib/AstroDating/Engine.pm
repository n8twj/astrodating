package AstroDating::Engine;

use strict;
use warnings;

use EV;
use Asterisk::AMI;
use AstroDating::Common;
use Scalar::Util qw/weaken/;
use Data::Dumper;

my $ami_reconnect_timer;
my $ami_connect_error = 0;
my $ami_was_connected = 0;

sub new {
	my $class = shift;
	my $self = {};
    bless($self, $class);
	$self->ami_attempt_connection();
	return $self;
}
sub ami_error_recovery {
	my ($self) = @_;
	$ami_connect_error++;
	weaken($self);
	$ami_reconnect_timer = EV::timer 5, 0, sub {
		$self->ami_attempt_connection();
	};
}
sub ami_attempt_connection {
	my $self = shift; 
	if ($ami_connect_error > 0) {
		$log->error("Connection error with Asterisk Manager Interface, retry #" . $ami_connect_error . "\n");
	}
	if ($AMI) {
		$AMI = undef;
	}
	weaken($self);
    $AMI = Asterisk::AMI->new(
					PeerAddr 	 => $config->{'ami_peer'},
					PeerPort 	 => $config->{'ami_port'},
					Username 	 => $config->{'ami_username'},
					Secret   	 => $config->{'ami_secret'},
					Events   	 => 'on',
					Timeout 	 => 0,
					Blocking 	 => 0,
					Handlers 	 => {	
										'Newchannel' => \&newchannel_ami_event,
										'Newstate'   => \&newstate_ami_event,
										'Newexten'   => \&newexten_ami_event,
										'Dial' 	  	 => \&dial_ami_event,
										'Link' 	  	 => \&link_ami_event,
										'Unlink' 	 => \&unlink_ami_event,
										'Hangup'  	 => \&hangup_ami_event,
										'UserEvent'  => \&userevent_ami_event
					},
					Keepalive 	   => 60,
					TCP_Keepalive  => 1,
					on_connect     => sub {
						my ($self) = @_;
						$ami_connect_error = 0;
						$self->send_action({ 'Action' => 'Ping' }, \&callback_ami_connected, 3);
					},
					on_error => sub {
						$log->error("### ON ERROR CALLED ###");
						$log->error(Dumper(@_));
						$self->ami_error_recovery();
					},
					on_connect_err => sub { 
						$log->error("### ON CONNECT ERROR CALLED ###");
						$log->error(Dumper(@_));
						$self->ami_error_recovery();
					},
					on_timeout => sub { 
						$log->error("### ON TIMEOUT CALLED ###");
						$log->error(Dumper(@_));
						$self->ami_error_recovery();
					},
				);
}
sub callback_ami_connected {
	my ($asterisk, @params) = @_;
	# Make sure our global reference to AMI poings to the proper object
    $AMI = $asterisk;
	$AMI_VER = $AMI->amiver();
 	$log->info("Connected to Asterisk Manager Interface ($AMI_VER)");
	if (!$ami_was_connected) {
	  $ami_was_connected = 1;
	}
}
sub __verbose_ami_event {
	my ($event,$calling_function) = @_;	
	print STDERR "[" . scalar (localtime) . "]: " . $calling_function . "(";
	my $comma = "";
	while ( my ($key, $value) = each %{$event} ) {
		print STDERR "$comma $key => '$value'";
		$comma = ",";
	}
	print STDERR ");\n";	
}
sub __process_event {
	my ($event) = @_;
	delete $event->{'Privilege'};
}
sub default_ami_event {
	my ($asterisk, $event) = @_;
	__verbose_ami_event($event, 'Default');
}
sub newchannel_ami_event {
	my ($asterisk, $event) = @_;
	#__verbose_ami_event($event, 'NewChannel');
	__process_event($event);
	my $channel = $event->{'Channel'};
	delete $event->{'Channel'};
	$active_data->{'active_channels'}{$channel} = $event; 
}
sub newstate_ami_event {
	my ($asterisk, $event) = @_;
	#__verbose_ami_event($event, 'NewState');
	__process_event($event);
	$active_data->{'active_channels'}->{$event->{'Channel'}}->{'State'} = $event->{'State'};
}
sub newexten_ami_event {
	my ($asterisk, $event) = @_;
	#__verbose_ami_event($event, 'NewExten');
	__process_event($event);
	my $channel = $event->{'Channel'};
	delete $event->{'Channel'};
	$active_data->{'active_extens'}->{$channel} = $event;
}
sub dial_ami_event {
	my ($asterisk, $event) = @_;
	#__verbose_ami_event($event, 'Dial');
	__process_event($event);	
}
sub link_ami_event {
	my ($asterisk, $event) = @_;
	#__verbose_ami_event($event, 'Link');	
	__process_event($event);
	$active_data->{'active_channels'}->{$event->{'Channel1'}} = { 'LinkedTo' => $event->{'Channel2'} };
	$active_data->{'active_channels'}->{$event->{'Channel2'}} = { 'LinkedTo' => $event->{'Channel1'} };
}
sub unlink_ami_event {
	my ($asterisk, $event) = @_;
	#__verbose_ami_event($event, 'Unlink');	
	__process_event($event);
	delete $active_data->{'active_channels'}->{$event->{'Channel1'}}->{'LinkedTo'};
	delete $active_data->{'active_channels'}->{$event->{'Channel2'}}->{'LinkedTo'};
}
sub hangup_ami_event {
	my ($asterisk, $event) = @_;
	#__verbose_ami_event($event, 'Hangup');
	__process_event($event);
	delete $active_data->{'active_extens'}->{$event->{'Channel'}};
	delete $active_data->{'active_channels'}->{$event->{'Channel'}};
}

sub userevent_ami_event {
	my ($asterisk, $event) = @_;	
	use 5.10.1;
	given ($event->{'UserEvent'}) { 
		when (/CallerEnterQueue/) {
			return;
		}
	}	
}

1;
