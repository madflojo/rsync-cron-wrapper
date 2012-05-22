#!/usr/bin/perl
###### rsync-cron-wrapper.pl | Benjamin Cane @ American Express Technologies
###### Created to provide an easy wrapper for putting rsync in cron
###### Usage: rsync-cron-wrapper.pl -c <config_file>
###### ------------------------------------------------------------
###### Version 1 - 05/11/2012
###### ------------------------------------------------------------
###### Features:
######  - Takes config file from command line to allow multiple rsync jobs
######  - Creates a PID file to prevent duplicate rsync runs
######  - Maintains a log file to output status and time taken
###### ------------------------------------------------------------

#### ------------
#### Perl Modules
#### ------------

### Debugging
use warnings;
use strict;

### Time
use POSIX;

#### ------------
#### Variables
#### ------------

my $conf_file	= qq();
my %conf_options; 
my $log_file	= qq();
my $pid_file	= qq();
my $continue	= 0;

#### ------------
#### SubRoutines
#### ------------

### Time for logfile
## &get_logheader();
sub get_logheader {
    my $time    = strftime( '%m/%d/%Y %T', localtime(time()));
    my $head    = qq{$time - $0\[$$]:};
    return $head ;
}

### Logging
## &log_this();
sub log_this {
        my $message             = shift; 
        my $message_type        = shift;
        if ( $message_type eq "death" ) {
                print LOG &get_logheader . $message . "\n";
                die($message . "\n");
        }
        elsif ( $message_type eq "silentdeath" ) {
                die($message . "\n");
        }
        elsif ( $message_type eq "hidden" ) {
                print LOG &get_logheader . $message . "\n";
        }
        elsif ( $message_type eq "output" ) {
                print $message . "\r\n\r\n";
        }
        else {
                print $message . "\r\n\r\n";
                print LOG &get_logheader . $message . "\n";
        }
        return;
}

#### ---------
#### Prep Work
#### ---------

### Check if cmd line arguments exist and set them
if (@ARGV) {
	if ($ARGV[0] eq "-c") {
		$conf_file	= qq($ARGV[1]);
	} else {
		&log_this("Usage: $0 -c <config_file>", "silentdeath");
	}
} else {
	
	&log_this("Usage: $0 -c <config_file>", "silentdeath");
}


### Parse Config file
## Open it
if ( -r $conf_file ) {
	open(CONF, "<$conf_file") || &log_this("[FATAL] Could not open configuration file $conf_file", "silentdeath");
} else {
	&log_this("[FATAL] Could not read configuration file $conf_file", "silentdeath");
}

my @conf_lines	= <CONF>;
my $line_count	= 1;
foreach my $conf_line (@conf_lines) {
	if ( $conf_line !~ m/^#/ && $conf_line !~ m/^\s*$/ ) {
		if ( $conf_line =~ m/^\[\[/ ) {
			my @breakdown = split(/\[\[|\]\]/, $conf_line);
			$conf_options{'JOB_NAME'} = $breakdown[1];
		} elsif ( $conf_line =~ m/^\[/ ) {
			my @breakdown2 = split(/\]\=/, $conf_line);
			chomp($breakdown2[1]);
			$breakdown2[0] =~ s/\s$//;
			$breakdown2[0] =~ s/^\[//;
			$breakdown2[1] =~ s/^\s*//;
			$conf_options{$breakdown2[0]} = $breakdown2[1];
		} else {
			&log_this("[STATUS] Strange syntax in the config file at line $line_count...", "output");
		}
	}
	$line_count++;
}

#### ----------
#### Execute
#### ----------

### Open Log
if ( $conf_options{'LOG_NAME'} ) {
	$log_file	= $conf_options{'LOG_DIR'} . "/" . $conf_options{'LOG_NAME'};
} else { 
	$log_file	= $conf_options{'LOG_DIR'} . "/" . $conf_options{'JOB_NAME'} . ".out";
}
open(LOG, ">>$log_file") || &log_this("[FATAL] Could not open log file $log_file", "silentdeath");

### Check then Create PID file
$pid_file	= $conf_options{'PID_DIR'} . "/" . $conf_options{'JOB_NAME'} . ".pid";
if ( ! -f $pid_file ) {
	open(PID, ">$pid_file") || &log_this("[FATAL] Could not create pid file $pid_file", "death");
	print PID $$;
	close(PID);
	$continue = 1;
} else {
	&log_this("[STATUS] Instance is already running", "hidden");
	$continue = 0;
}

### Start the rsync process if ok to continue
if ( $continue == 1 ) {
	&log_this("[STATUS] Starting rsync process with command $conf_options{'RSYNC_CMD'}", "hidden");
	my $start = time();
	my $return_code = system($conf_options{'RSYNC_CMD'});
	if ( $return_code == 0 ) {
		my $finish	= time();
		my $total	= $finish - $start;
		&log_this("[STATUS] rsync process complete; completed in $total seconds", "hidden");
	} else {
		&log_this("[FATAL] rsync process failed.. uh oh. check your rsync log or specify one in the config with the --log-file=FILE option", "death");
	}	
## Clean up pid file when finished
unlink($pid_file);
}

### Close Log
close(LOG);
