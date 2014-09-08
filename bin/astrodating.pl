#!/usr/bin/env perl
use strict; 
use warnings;
use FindBin;
use EV;
use lib "$FindBin::Bin/../lib";
use Proc::PID::File;

# Exit if already running
my $pp = Proc::PID::File->new();

require AstroDating::Engine;
my $engine = new AstroDating::Engine();
EV::loop;


1;