#############################################################################################
# Release Beta 0.8
# Jerome.blanchet@NetApp.com
#
# A use full script can to debug Snadiff 7-mode or cDOT (Windows and Linux)
#
#############################################################################################
use warnings;
use Getopt::Long;
use Config;
use Term::ReadKey;
#############################################################################################
# TEST OS DEPENDENCY
#############################################################################################
#
my $default_config_file ;
my $LOGFILE ;

if ( $Config{osname} eq 'MSWin32' )  {
	use lib 'C:\Program Files\NetApp\perl\lib';
	$default_config_file='C:\Program Files\NetApp\perl\etc\snapdiff.conf';
	$LOGFILE='C:\Program Files\NetApp\perl\log\snapdiff.log';
} else {
	use lib '/usr/lib/NetApp/perl';
	$default_config_file='/home/netapadm/.NetApp/snapdiff.conf';
	$LOGFILE='/home/netapadm/log/snapdiff.log';
}
use NaServer;
use NaElement;
use Data::Dumper;

#############################################################################################
# LOCAL VARS
#############################################################################################
my $CONFIG_FILE = "" ;
my $HOSTNAME = "" ;
my $LOGIN = "";
my $PASSWD = "";
my $VOLUME = "";
my $SNAP1 = "";
my $SNAP2 = "";
my $PORT = 80 ;
my $PROTOCOL = 'HTTP' ;
my $debug = 0 ;
my $EPOCH  = "" ;
my $TIMESTAMP = "" ;
my $CDOT = "" ;
my $APP_NAME = "snapdiff_debug" ;
my $APP_TYPE = "perl_snapdiff" ;

#############################################################################################
# Functions
sub get_timestamp {
	my $sec ; my $min ; my $hour ; my $mday ; my $mon ; my $year ; my $wday ;
	my $yday ; my $isdst ; my $timestamp ;
	($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst) = localtime(time);
	$year = sprintf("%04d", $year + 1900 );
	$mon  = sprintf("%02d", $mon +  1 );
	$timestamp = sprintf("%04d_%02d_%02d %02d:%02d:%02d", $year, $mon, $mday, $hour, $min, $sec) ;
	return $timestamp ;
}


#############################################################################################
sub print_help {
	print ("\n\n\nUsage: snapdiff [options]\n\n") ;
	print ("All available options are: \n") ;
	print ("	 --hostname 	[HOSTNAME]	\n") ;
	print ("	 --login 	[LOGIN]	\n") ;
	print ("	 --passwd 	[PASSWD]	\n") ;
	print ("	 --volume 	[VOLUME]	\n") ;
	print ("	 --snap1 	[SNAP1]	\n") ;
	print ("	 --snap2 	[SNAP2]	\n") ;
	print ("	 --debug 	[0|1|2] 	\n") ;
	print ("	 --protocol  	[HTTP|HTTPS] \n") ;
	print ("	 --port 	[PORT] \n\n\n") ;
	print ("All options can be enter in configuation file instead.\n") ;
	print ("The default configuration file: $default_config_file\n") ;
}

#############################################################################################
# PrintLog
sub printlog {
	$logtime = get_timestamp() ;
	open(my $out, ">>", "$LOGFILE" )
		or die "ERROR: Unable to open $LOGFILE for write $!";
    	 print $out "$logtime: @_\n" ; 
	 print "$logtime: @_\n" ; 
}
#############################################################################################
# print_debug
sub print_debug {
        if($debug gt 0){printlog "DEBUG:".$_[0];}
}

#############################################################################################
# read_config_file
sub read_config_file {
	my ($config_file) = @_;
	if ( -r $config_file ) {
		print ("INFO: read configuration File [$config_file]\n") ;
		open my $config, '<', $config_file or die "ERROR: $config_file $!" ;
		while(<$config>) {
        		chomp;
			(my $key, my @value) = split /=/, $_;
        		$config{$key} = join '=', @value;
		}
		if ($config{DEBUG}) {
       	 		$DEBUG="$config{DEBUG}" ;
       	 		printlog ("DEBUG : [$DEBUG]") ;
			$debug = $DEBUG ;
		}

		if ($config{HOSTNAME}) {
        		$HOSTNAME="$config{HOSTNAME}" ;
		}

		if ($config{PORT}) {
        		$PORT="$config{PORT}" ;
		}

		if ($config{PROTOCOL}) {
        		$PROTOCOL="$config{PROTOCOL}" ;
		}

		if ($config{LOGIN}) {
        		$LOGIN="$config{LOGIN}" ;
		}

		if ($config{PASSWD}) {
        		$PASSWD="$config{PASSWD}" ;
		}
		if ($config{VOLUME}) {
        		$VOLUME="$config{VOLUME}" ;
		}
		if ($config{SNAP1}) {
        		$SNAP1="$config{SNAP1}" ;
		}
		if ($config{SNAP2}) {
        		$SNAP2="$config{SNAP2}" ;
		}
		if ($config{CDOT}) {
        		$CDOT="$config{CDOT}" ;
		}

	} else {
		print ("INFO: No configuration File found [$config_file]\n") ;
	}
}

################################################################################################
# connect_server ([dfm_hostname],[user_name],[password],[port]) 
sub connect_server {
	my ($hostname,$user,$password,$protocol,$port) = @_;
	
	my $server = new NaServer($hostname, 1, 20);
	$server->set_server_type('FILER');
	$server->set_transport_type($protocol);
	$server->set_style('LOGIN');
	$server->set_admin_user($user, $password);
	$server->set_port($port);
	return $server ;
}

################################################################################################
sub snapdiff {
	my ($server,$volume_name,$base_snapshot,$diff_snapshot,$app_name,$app_type) = @_;

	printlog "snapdiff-iter-start" ;
	my $api = new NaElement('snapdiff-iter-start');
	$api->child_add_string('volume',$volume_name);
	$api->child_add_string('base-snapshot',$base_snapshot);
	$api->child_add_string('diff-snapshot',$diff_snapshot);
	$api->child_add_string('file-access-protocol','nfs');
	$api->child_add_string('max-diffs','256');
	if (defined $app_name && length $app_name > 0) {
		$api->child_add_string('application-name',$app_name);
	}
	if (defined $app_type && length $app_type > 0) {
		$api->child_add_string('application-type',$app_type);
	}
	if ( $debug gt 0 ) { printf $api->sprintf(); }

	my $output = $server->invoke_elem($api);
	if ($output->results_status() eq 'failed') {
		printlog("ERROR: ".$output->sprintf());
		return ;
	}
	$session_id = $output->child_get_string("session-id") ;
	print_debug "session-id: $session_id" ;

	printlog "snapdiff-iter-next" ;
	$api = new NaElement('snapdiff-iter-next');	
	$api->child_add_string('session-id',$session_id);
	if ( $debug gt 0 ) { printf $api->sprintf(); }

	$output = $server->invoke_elem($api);
	if ($output->results_status() eq 'failed') {
        	printlog("ERROR: ".$output->sprintf());
        	return ;
	}
	if ( $debug gt 1 ) { print Dumper $output ; }
	if ( $debug gt 0 ) { printf $output->sprintf(); }

	$output_tmp = $output->child_get('snapshot-changes') ;		
	if ( $debug gt 1 ) { print Dumper $output_tmp ; }
	if ( $debug gt 0 ) { printf $output_tmp->sprintf(); }
	@filename_infos_list = $output_tmp->children_get() ;
	foreach my $filename_infos (@filename_infos_list) {
		        $filename = $filename_infos->child_get_string("filename");
			printlog ("filename: $filename") ;
		}

	printlog "snapdiff-iter-status" ;
	$api = new NaElement('snapdiff-iter-status');	
	$api->child_add_string('session-id', $session_id) ;
	$output = $server->invoke_elem($api);
	if ($output->results_status() eq 'failed') {
        	printlog("ERROR: ".$output->sprintf());
        	return ;
	}
	if ( $debug gt 0 ) { printf $output->sprintf(); }
        $status = $output->child_get_string("session-status");
	printlog ("snapdiff-iter-status: $status") ;
}



#############################################################################################
# MAIN
#############################################################################################
# Read Default configuration file
read_config_file $default_config_file ;
# Get Options
GetOptions ("debug=i"  => 	\$debug,
            "hostname=s" => 	\$HOSTNAME,
            "login=s" => 	\$LOGIN,
            "passwd=s" => 	\$PASSWD,
            "volume=s" => 	\$VOLUME,
            "snap1=s"  => 	\$SNAP1,
            "snap2=s"  => 	\$SNAP2,
            "protocol=s"  => 	\$PROTOCOL,
            "port=s"  => 	\$PORT,
            "cdot"  	=>	\$CDOT,
            "config_file=s"  =>	\$CONFIG_FILE,
            "help"  => sub { print_help ; exit } )	
or die("Error in command line arguments\n");

if ( $CONFIG_FILE  ne ""  ) {
	print ("CONFIG_FILE 		: [$CONFIG_FILE]\n") ;
	read_config_file $CONFIG_FILE
}

if ( ( $HOSTNAME eq "" ) or ( $LOGIN eq "" ) or ( $VOLUME eq "") or ( $SNAP1 eq "" ) or ( $SNAP2 eq "" ) ) {
	print ("ERROR: syntax error or missing parameter in configuration file\n\n") ;
	print ("HOSTNAME	: [$HOSTNAME]\n" ) ;
	print ("PORT 		: [$PORT]\n") ;
	print ("PROTOCOL 	: [$PROTOCOL] \n" ) ;
	print ("LOGIN		: [$LOGIN]\n") ;
	print ("VOLUME		: [$VOLUME]\n") ;
	print ("SNAP1		: [$SNAP1]\n") ;
	print ("SNAP2		: [$SNAP2]\n\n\n") ;
	print ("run --help option for more help\n") ;
	exit 1 ;
}

if ( $CDOT ) {
	if ( ( $APP_NAME eq "" ) or ( $APP_TYPE eq "" ) ) {
		print ("APP_NAME	: [$SNAP1]\n") ;
		print ("APP_TYPE	: [$SNAP2]\n\n\n") ;
		exit 1 ;
	}
}

if ( ( $PASSWD eq "" ) ) {
	print "Enter Password: ";
	ReadMode( "noecho");
	$PASSWD = readline(*STDIN);
	chomp $PASSWD;
	ReadMode ("original") ; 
}
printlog ("debug	: [$debug]") ;
printlog ("HOSTNAME	: [$HOSTNAME] " ) ;
printlog ("PORT 	: [$PORT]") ;
printlog ("PROTOCOL 	: [$PROTOCOL] " ) ;
printlog ("LOGIN	: [$LOGIN]") ;
printlog ("VOLUME	: [$VOLUME]") ;
printlog ("SNAP1	: [$SNAP1]") ;
printlog ("SNAP2	: [$SNAP2]") ;
printlog ("CDOT 	: [$CDOT]\n\n\n") ;

# GET TIME
$TIMESTAMP=get_timestamp() ;
$EPOCH=time ;


# Connection to server
$my_server=connect_server($HOSTNAME,$LOGIN,$PASSWD,$PROTOCOL,$PORT) ;
if ( ! defined($my_server) ) {
	printlog ("ERROR: Failed to connect to server $HOSTNAME" );
	exit 1 ;
}
if ( $CDOT ) {
	snapdiff($my_server,$VOLUME,$SNAP1,$SNAP2,$APP_NAME,$APP_TYPE); 
} else {
	snapdiff($my_server,$VOLUME,$SNAP1,$SNAP2); 
}
exit 1
